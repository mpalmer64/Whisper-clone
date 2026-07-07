import AVFoundation
import SwiftUI

/// Drives the dictation session in the companion app. The keyboard extension
/// can't record (iOS forbids it), so recording and Whisper both live here.
@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case loadingModel
        case ready
        case recording
        case transcribing
        case finished(String)
        case failed(String)
    }

    @Published var phase: Phase = .loadingModel
    @Published var level: Float = 0
    @Published var micGranted = true
    /// True when we were launched by the keyboard (whisperkey://dictate) and
    /// should start listening the moment the model is ready.
    @Published var launchedFromKeyboard = false

    let settings = Settings.shared

    private let recorder = AudioRecorder()
    private let transcriber = Transcriber()
    private var modelReady = false
    private var autoStartPending = false

    // MARK: - Startup

    func bootstrap() async {
        micGranted = await requestMicrophone()
        await loadModel()
    }

    func handle(url: URL) {
        guard url.scheme == "whisperkey" else { return }
        launchedFromKeyboard = true
        if case .recording = phase { return }
        if modelReady {
            startRecording()
        } else {
            autoStartPending = true
        }
    }

    func reloadModel() {
        Task { await loadModel() }
    }

    private func loadModel() async {
        modelReady = false
        phase = .loadingModel
        do {
            try await transcriber.load(modelID: settings.modelID)
            modelReady = true
            if autoStartPending {
                autoStartPending = false
                startRecording()
            } else {
                phase = .ready
            }
        } catch {
            phase = .failed("Couldn't download the speech model. Check your connection, then tap Retry.")
        }
    }

    private func requestMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard modelReady, phase != .recording else { return }
        guard micGranted else {
            phase = .failed("Microphone access is off. Enable it in Settings → WhisperKey.")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: [])

            recorder.onLevel = { [weak self] level in
                MainActor.assumeIsolated { self?.level = level }
            }
            try recorder.start()
            phase = .recording
        } catch {
            phase = .failed("Couldn't start the microphone. Close other audio apps and try again.")
        }
    }

    func cancelRecording() {
        recorder.cancel()
        deactivateSession()
        phase = .ready
    }

    func stopAndTranscribe() {
        guard phase == .recording else { return }
        let audio = recorder.stop()
        deactivateSession()

        guard audio.count > Int(AudioRecorder.sampleRate * 0.35) else {
            phase = .ready
            return
        }

        phase = .transcribing
        let removeFillers = settings.removeFillers
        Task {
            do {
                let raw = try await transcriber.transcribe(audio)
                let text = TranscriptCleaner.clean(raw, removeFillers: removeFillers)
                guard !text.isEmpty else {
                    self.phase = .failed("No speech detected — try again.")
                    return
                }
                SharedTranscript.write(text)
                UIPasteboard.general.string = text
                self.phase = .finished(text)
            } catch {
                self.phase = .failed("Transcription failed — try again.")
            }
        }
    }

    func resetForNextDictation() {
        phase = modelReady ? .ready : .loadingModel
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
