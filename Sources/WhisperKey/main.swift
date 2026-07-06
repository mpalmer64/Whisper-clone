import AppKit

// WhisperKey — hold the fn key, speak, release. Your words are typed
// into whatever app you're using. 100% on-device via WhisperKit.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu bar only — no dock icon, no main window.
app.setActivationPolicy(.accessory)
app.run()
