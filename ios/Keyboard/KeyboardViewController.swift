import UIKit

/// The WhisperKey keyboard: a slim dictation bar, not a full QWERTY
/// replacement. Tap the mic → the WhisperKey app opens and records →
/// swipe back → the transcript is typed into the focused field.
///
/// You keep your normal keyboard for typing; the globe key hops between them.
final class KeyboardViewController: UIInputViewController {
    private let statusLabel = UILabel()
    private let dictateButton = UIButton(type: .system)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        insertPendingTranscriptIfAny()
        refreshStatus()
    }

    // MARK: - Transcript handoff

    private func insertPendingTranscriptIfAny() {
        guard hasFullAccess else { return }
        guard let text = SharedTranscript.consumePending() else { return }

        // If there's already text right before the cursor, add a space so
        // dictations don't glue onto the previous word.
        if let before = textDocumentProxy.documentContextBeforeInput,
           let last = before.last, !last.isWhitespace && !last.isNewline {
            textDocumentProxy.insertText(" ")
        }
        textDocumentProxy.insertText(text)
        statusLabel.text = "✓ Inserted"
    }

    private func refreshStatus() {
        if !hasFullAccess {
            statusLabel.text = "Enable “Allow Full Access” in Settings → General → Keyboard → Keyboards → WhisperKey"
            dictateButton.isEnabled = false
        } else if statusLabel.text?.hasPrefix("✓") != true {
            statusLabel.text = "Tap the mic, speak in the WhisperKey app, then swipe back here"
            dictateButton.isEnabled = true
        }
    }

    // MARK: - Actions

    @objc private func dictateTapped() {
        statusLabel.text = "Opening WhisperKey…"
        openContainerApp(URL(string: "whisperkey://dictate")!)
    }

    /// Keyboard extensions can't call UIApplication.open directly; walking
    /// the responder chain to the host's UIApplication and performing the
    /// legacy openURL: selector is the long-standing workaround used by
    /// dictation keyboards (Wispr Flow does the same bounce).
    private func openContainerApp(_ url: URL) {
        let selector = sel_registerName("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector), !(current is UIViewController) {
                current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
        statusLabel.text = "Couldn't open the app — launch WhisperKey manually"
    }

    @objc private func deleteTapped() {
        textDocumentProxy.deleteBackward()
    }

    @objc private func spaceTapped() {
        textDocumentProxy.insertText(" ")
    }

    @objc private func returnTapped() {
        textDocumentProxy.insertText("\n")
    }

    // MARK: - UI

    private func buildUI() {
        view.backgroundColor = .clear

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.adjustsFontSizeToFitWidth = true
        statusLabel.minimumScaleFactor = 0.7

        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "mic.fill")
        config.title = "Dictate"
        config.imagePadding = 8
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemBlue
        dictateButton.configuration = config
        dictateButton.addTarget(self, action: #selector(dictateTapped), for: .touchUpInside)

        let globe = makeKey(symbol: "globe")
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        globe.isHidden = !needsInputModeSwitchKey

        let space = makeKey(symbol: "space")
        space.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)

        let delete = makeKey(symbol: "delete.left")
        delete.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        let ret = makeKey(symbol: "return")
        ret.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)

        let keyRow = UIStackView(arrangedSubviews: [globe, space, delete, ret])
        keyRow.axis = .horizontal
        keyRow.spacing = 8
        keyRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [statusLabel, dictateButton, keyRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            dictateButton.heightAnchor.constraint(equalToConstant: 56),
            keyRow.heightAnchor.constraint(equalToConstant: 40),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])
    }

    private func makeKey(symbol: String) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.gray()
        if symbol == "space" {
            config.title = "space"
        } else {
            config.image = UIImage(systemName: symbol)
        }
        config.cornerStyle = .medium
        button.configuration = config
        return button
    }
}
