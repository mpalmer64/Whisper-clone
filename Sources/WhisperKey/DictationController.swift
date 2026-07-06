import AppKit
import ServiceManagement

/// Orchestrates the whole flow:
/// fn down → record → fn up → transcribe → clean → paste.
/// Also owns the menu bar item and all user-facing state.
@MainActor
final class DictationController: NSObject {
    private enum State {
        case idle
        case loadingModel
        case recording
        case transcribing
    }

    private var state: State = .idle
    private var modelReady = false

    private let settings = Settings.shared
    private let monitor = FnKeyMonitor()
    private let recorder = AudioRecorder()
    private let transcriber = Transcriber()
    private let overlay = OverlayIndicator()

    private var statusItem: NSStatusItem!
    private var accessibilityPollTimer: Timer?
    private var maxDurationTimer: Timer?
    private var recordingStartedAt: Date?
    private var recentTranscripts: [String] = []

    private static let escKeyCode: Int64 = 53
    private static let minRecordingSeconds: TimeInterval = 0.35
    private static let maxRecordingSeconds: TimeInterval = 600

    // MARK: - Startup

    func start() {
        setUpStatusItem()

        // FnKeyMonitor invokes these on the main queue; assumeIsolated makes
        // the hop back onto the main actor explicit for the compiler.
        monitor.onFnDown = { [weak self] in
            MainActor.assumeIsolated { self?.handleFnDown() }
        }
        monitor.onFnUp = { [weak self] in
            MainActor.assumeIsolated { self?.handleFnUp() }
        }
        monitor.onKeyDown = { [weak self] keyCode in
            MainActor.assumeIsolated {
                guard let self, keyCode == Self.escKeyCode, self.state == .recording else { return }
                self.cancelRecording()
            }
        }

        Task {
            let micOK = await Permissions.requestMicrophone()
            if !micOK {
                self.showError("Microphone access denied — enable it in System Settings → Privacy & Security → Microphone")
            }
        }

        Permissions.checkAccessibility(promptIfNeeded: true)
        startMonitorWhenTrusted()
        loadModel()
    }

    /// Accessibility permission may be granted after launch (the user flips a
    /// toggle in System Settings). Poll until the event tap can be created.
    private func startMonitorWhenTrusted() {
        if monitor.start() {
            refreshMenu()
            return
        }
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.monitor.start() {
                    self.accessibilityPollTimer?.invalidate()
                    self.accessibilityPollTimer = nil
                    self.refreshMenu()
                }
            }
        }
    }

    private func loadModel() {
        modelReady = false
        state = .loadingModel
        updateStatusIcon()
        refreshMenu()

        let modelID = settings.modelID
        Task {
            do {
                try await transcriber.load(modelID: modelID)
                self.modelReady = true
                self.state = .idle
            } catch {
                self.state = .idle
                self.showError("Couldn't load model “\(modelID)” — check your internet connection and try again from the menu")
            }
            self.updateStatusIcon()
            self.refreshMenu()
        }
    }

    // MARK: - fn key handling

    private func handleFnDown() {
        switch settings.mode {
        case .hold:
            if state == .idle { beginRecording() }
        case .toggle:
            switch state {
            case .idle: beginRecording()
            case .recording: finishRecording()
            default: break
            }
        }
    }

    private func handleFnUp() {
        guard settings.mode == .hold, state == .recording else { return }
        finishRecording()
    }

    // MARK: - Recording lifecycle

    private func beginRecording() {
        guard modelReady else {
            overlay.show(.error(state == .loadingModel ? "Model still loading…" : "Model not loaded"))
            return
        }

        do {
            recorder.onLevel = { [weak self] level in
                MainActor.assumeIsolated { self?.overlay.pushLevel(level) }
            }
            try recorder.start()
        } catch {
            showError(error.localizedDescription)
            return
        }

        state = .recording
        recordingStartedAt = Date()
        overlay.show(.recording)
        updateStatusIcon()
        playSound("Pop")

        maxDurationTimer?.invalidate()
        maxDurationTimer = Timer.scheduledTimer(withTimeInterval: Self.maxRecordingSeconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state == .recording else { return }
                self.finishRecording()
            }
        }
    }

    private func cancelRecording() {
        guard state == .recording else { return }
        maxDurationTimer?.invalidate()
        recorder.cancel()
        state = .idle
        overlay.hide()
        updateStatusIcon()
    }

    private func finishRecording() {
        guard state == .recording else { return }
        maxDurationTimer?.invalidate()

        let audio = recorder.stop()
        let duration = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        recordingStartedAt = nil

        // Accidental tap of fn — nothing worth transcribing.
        guard duration >= Self.minRecordingSeconds,
              audio.count >= Int(AudioRecorder.sampleRate * Self.minRecordingSeconds) else {
            state = .idle
            overlay.hide()
            updateStatusIcon()
            return
        }

        state = .transcribing
        overlay.show(.transcribing)
        updateStatusIcon()

        let removeFillers = settings.removeFillers
        Task {
            do {
                let raw = try await transcriber.transcribe(audio)
                let text = TranscriptCleaner.clean(raw, removeFillers: removeFillers)
                self.state = .idle
                self.updateStatusIcon()

                guard !text.isEmpty else {
                    self.overlay.show(.error("No speech detected"))
                    return
                }

                TextInjector.insert(text)
                self.rememberTranscript(text)
                self.overlay.show(.success("Typed \(text.count) characters"))
                self.playSound("Tink")
            } catch {
                self.state = .idle
                self.updateStatusIcon()
                self.overlay.show(.error("Transcription failed"))
            }
        }
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusIcon()
        refreshMenu()
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        let (symbol, description): (String, String)
        switch state {
        case .idle: (symbol, description) = ("mic", "WhisperKey — idle")
        case .loadingModel: (symbol, description) = ("arrow.down.circle", "WhisperKey — loading model")
        case .recording: (symbol, description) = ("mic.fill", "WhisperKey — recording")
        case .transcribing: (symbol, description) = ("waveform", "WhisperKey — transcribing")
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        button.appearsDisabled = (state == .loadingModel)
    }

    private func refreshMenu() {
        let menu = NSMenu()

        // Status line
        let statusTitle: String
        if !monitor.isRunning {
            statusTitle = "⚠ Grant Accessibility permission to enable fn key"
        } else if state == .loadingModel {
            statusTitle = "Downloading / loading model…"
        } else if !modelReady {
            statusTitle = "⚠ Model not loaded"
        } else {
            statusTitle = settings.mode == .hold
                ? "Ready — hold fn and speak"
                : "Ready — tap fn to start and stop"
        }
        let statusLine = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        if !monitor.isRunning {
            menu.addItem(makeItem("Open Accessibility Settings…", action: #selector(openAccessibilitySettings)))
        }

        menu.addItem(.separator())

        // Model picker
        let modelMenu = NSMenu()
        for model in WhisperModel.all {
            let item = NSMenuItem(title: "\(model.label) — \(model.detail)", action: #selector(selectModel(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = model.id
            item.state = (model.id == settings.modelID) ? .on : .off
            modelMenu.addItem(item)
        }
        let modelItem = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        modelItem.submenu = modelMenu
        menu.addItem(modelItem)

        // Activation mode
        let modeMenu = NSMenu()
        for mode in ActivationMode.allCases {
            let item = NSMenuItem(title: mode.label, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = (mode == settings.mode) ? .on : .off
            modeMenu.addItem(item)
        }
        let modeItem = NSMenuItem(title: "Activation", action: nil, keyEquivalent: "")
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        // Toggles
        let fillersItem = makeItem("Remove Filler Words (um, uh)", action: #selector(toggleFillers))
        fillersItem.state = settings.removeFillers ? .on : .off
        menu.addItem(fillersItem)

        let soundItem = makeItem("Sound Effects", action: #selector(toggleSound))
        soundItem.state = settings.soundFeedback ? .on : .off
        menu.addItem(soundItem)

        let loginItem = makeItem("Launch at Login", action: #selector(toggleLaunchAtLogin))
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(loginItem)

        // Recent transcripts
        if !recentTranscripts.isEmpty {
            menu.addItem(.separator())
            let recentMenu = NSMenu()
            for transcript in recentTranscripts {
                let title = transcript.count > 60 ? String(transcript.prefix(60)) + "…" : transcript
                let item = NSMenuItem(title: title, action: #selector(copyTranscript(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = transcript
                recentMenu.addItem(item)
            }
            let recentItem = NSMenuItem(title: "Recent (click to copy)", action: nil, keyEquivalent: "")
            recentItem.submenu = recentMenu
            menu.addItem(recentItem)
        }

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit WhisperKey", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func makeItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    // MARK: - Menu actions

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let modelID = sender.representedObject as? String, modelID != settings.modelID else { return }
        settings.modelID = modelID
        loadModel()
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = ActivationMode(rawValue: raw) else { return }
        settings.mode = mode
        refreshMenu()
    }

    @objc private func toggleFillers() {
        settings.removeFillers.toggle()
        refreshMenu()
    }

    @objc private func toggleSound() {
        settings.soundFeedback.toggle()
        refreshMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showError("Couldn't change Launch at Login (move the app to /Applications first)")
        }
        refreshMenu()
    }

    @objc private func copyTranscript(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        TextInjector.copyOnly(text)
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Helpers

    private func rememberTranscript(_ text: String) {
        recentTranscripts.insert(text, at: 0)
        if recentTranscripts.count > 5 {
            recentTranscripts.removeLast(recentTranscripts.count - 5)
        }
        refreshMenu()
    }

    private func playSound(_ name: String) {
        guard settings.soundFeedback else { return }
        NSSound(named: name)?.play()
    }

    private func showError(_ message: String) {
        overlay.show(.error(message))
    }
}
