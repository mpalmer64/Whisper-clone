import AppKit
import CoreGraphics

/// Watches the fn (🌐) key system-wide using a listen-only CGEvent tap.
///
/// The fn key doesn't produce normal keyDown/keyUp events — it arrives as a
/// `.flagsChanged` event with keycode 63, and its pressed state is reflected
/// in the `.maskSecondaryFn` flag. We also listen for plain keyDowns so the
/// controller can cancel a recording with Esc.
///
/// Requires Accessibility permission (System Settings → Privacy & Security).
final class FnKeyMonitor {
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?
    /// Called with the keycode of any regular key press (used for Esc-to-cancel).
    var onKeyDown: ((Int64) -> Void)?

    private(set) var isRunning = false
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnIsDown = false

    private static let fnKeyCode: Int64 = 63

    /// Returns false if the event tap could not be created — almost always
    /// because Accessibility permission hasn't been granted yet.
    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handle(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isRunning = false
        fnIsDown = false
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // macOS disables taps that stall or when secure input kicks in; re-arm.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .keyDown {
            let code = keyCode
            DispatchQueue.main.async { [weak self] in
                self?.onKeyDown?(code)
            }
            return
        }

        guard type == .flagsChanged, keyCode == Self.fnKeyCode else { return }

        let isDown = event.flags.contains(.maskSecondaryFn)
        guard isDown != fnIsDown else { return }
        fnIsDown = isDown

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isDown ? self.onFnDown?() : self.onFnUp?()
        }
    }
}
