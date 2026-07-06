import ApplicationServices
import AVFoundation

enum Permissions {
    /// Accessibility trust is required both to watch the fn key (event tap)
    /// and to post the synthetic Cmd+V that pastes the transcript.
    @discardableResult
    static func checkAccessibility(promptIfNeeded: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptIfNeeded
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }
}
