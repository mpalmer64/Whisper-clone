import AppKit
import CoreGraphics

/// Inserts text into whatever app has keyboard focus.
///
/// Strategy: put the text on the pasteboard, synthesize Cmd+V, then restore
/// whatever was on the pasteboard before. Pasting is the only insertion
/// method that works reliably in every app (browsers, Electron apps,
/// terminals, native text fields) and it's instant for long text.
enum TextInjector {
    static func insert(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Snapshot the current pasteboard so we can restore it after pasting.
        let savedItems: [NSPasteboardItem] = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        postCmdV()

        // Give the target app a moment to read the pasteboard, then restore.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            pasteboard.clearContents()
            if !savedItems.isEmpty {
                pasteboard.writeObjects(savedItems)
            }
        }
    }

    /// Copies to the clipboard without pasting (fallback / menu action).
    static func copyOnly(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func postCmdV() {
        let vKey: CGKeyCode = 9
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
