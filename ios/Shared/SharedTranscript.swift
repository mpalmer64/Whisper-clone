import Foundation

/// The handoff between the WhisperKey app and the keyboard extension.
///
/// iOS forbids keyboard extensions from using the microphone, so the keyboard
/// bounces you to the app to record. The app writes the finished transcript
/// here (an App Group shared container); when you swipe back, the keyboard
/// consumes it and types it into the focused text field.
enum SharedTranscript {
    /// Must match the App Group in both targets' entitlements (project.yml).
    static let appGroupID = "group.com.whisperkey.shared"

    /// Transcripts older than this are ignored, so a forgotten dictation
    /// doesn't get pasted into an unrelated app the next day.
    static let maxAge: TimeInterval = 180

    private static let textKey = "pendingTranscriptText"
    private static let dateKey = "pendingTranscriptDate"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func write(_ text: String) {
        guard let defaults else { return }
        defaults.set(text, forKey: textKey)
        defaults.set(Date().timeIntervalSince1970, forKey: dateKey)
    }

    /// Returns the pending transcript (if fresh) and clears it, so it is
    /// inserted exactly once.
    static func consumePending() -> String? {
        guard let defaults,
              let text = defaults.string(forKey: textKey),
              !text.isEmpty
        else { return nil }

        let created = Date(timeIntervalSince1970: defaults.double(forKey: dateKey))
        defaults.removeObject(forKey: textKey)
        defaults.removeObject(forKey: dateKey)

        guard Date().timeIntervalSince(created) <= maxAge else { return nil }
        return text
    }
}
