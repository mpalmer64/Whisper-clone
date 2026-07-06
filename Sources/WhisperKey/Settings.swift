import Foundation

enum ActivationMode: String, CaseIterable {
    /// Hold fn to record, release to transcribe (like Wispr Flow).
    case hold
    /// Tap fn to start, tap again to stop.
    case toggle

    var label: String {
        switch self {
        case .hold: return "Hold fn to talk"
        case .toggle: return "Tap fn to start / stop"
        }
    }
}

struct WhisperModel {
    let id: String       // WhisperKit model variant
    let label: String    // Menu label
    let detail: String   // Size / speed hint

    static let all: [WhisperModel] = [
        WhisperModel(id: "tiny.en", label: "Tiny (English)", detail: "fastest, least accurate · ~75 MB"),
        WhisperModel(id: "base.en", label: "Base (English)", detail: "fast, good accuracy · ~150 MB"),
        WhisperModel(id: "small.en", label: "Small (English)", detail: "best balance · ~500 MB"),
        WhisperModel(id: "large-v3", label: "Large v3 (all languages)", detail: "most accurate, slower · ~3 GB"),
    ]

    static let defaultID = "base.en"
}

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let model = "modelID"
        static let mode = "activationMode"
        static let removeFillers = "removeFillers"
        static let soundFeedback = "soundFeedback"
    }

    var modelID: String {
        get { defaults.string(forKey: Key.model) ?? WhisperModel.defaultID }
        set { defaults.set(newValue, forKey: Key.model) }
    }

    var mode: ActivationMode {
        get { ActivationMode(rawValue: defaults.string(forKey: Key.mode) ?? "") ?? .hold }
        set { defaults.set(newValue.rawValue, forKey: Key.mode) }
    }

    var removeFillers: Bool {
        get { defaults.object(forKey: Key.removeFillers) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.removeFillers) }
    }

    var soundFeedback: Bool {
        get { defaults.object(forKey: Key.soundFeedback) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.soundFeedback) }
    }
}
