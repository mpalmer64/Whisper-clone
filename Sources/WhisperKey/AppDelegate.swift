import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: DictationController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = DictationController()
        self.controller = controller
        controller.start()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
