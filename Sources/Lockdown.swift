import AppKit
import IOKit.pwr_mgt

/// Swallows every input event system-wide. If macOS disables the tap
/// (timeout or secure input), it is switched straight back on.
private let swallow: CGEventTapCallBack = { _, type, event, refcon in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon, let tap = Unmanaged<Lockdown>.fromOpaque(refcon).takeUnretainedValue().tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }
    return nil
}

/// Holds the machine: kiosk presentation options, a global input tap,
/// a frozen hidden cursor and a display-sleep assertion.
///
/// Everything here is owned by this process, so if it ever crashes the OS
/// drops all of it and the Mac is usable again.
final class Lockdown {
    enum Failure: Error { case tapUnavailable }

    private(set) var isEngaged = false
    fileprivate var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var sleepAssertion: IOPMAssertionID = 0
    private var watchdog: DispatchWorkItem?

    private var pointerLocked = false

    /// Keyboard, modifier keys and media/brightness keys (NX_SYSDEFINED).
    private static let keyboardMask: CGEventMask =
        [CGEventType.keyDown, .keyUp, .flagsChanged]
            .reduce(CGEventMask(1 << 14)) { $0 | (1 << $1.rawValue) }

    func engage(for duration: TimeInterval, lockPointer: Bool, keepAwake: Bool) throws {
        guard !isEngaged else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: lockPointer ? CGEventMask.max : Self.keyboardMask,
            callback: swallow,
            userInfo: refcon
        ) else { throw Failure.tapUnavailable }

        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        NSApp.presentationOptions = [
            .hideDock, .hideMenuBar, .disableAppleMenu,
            .disableProcessSwitching, .disableForceQuit,
            .disableSessionTermination, .disableHideApplication,
        ]

        if lockPointer {
            CGAssociateMouseAndMouseCursorPosition(0)
            NSCursor.hide()
        }
        pointerLocked = lockPointer

        if keepAwake {
            IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Cloister session" as CFString,
                &sleepAssertion
            )
        }

        // Last-resort fail-safe on a background queue: if the main thread
        // ever hangs past the deadline, the process exits and the OS
        // releases everything above.
        let item = DispatchWorkItem { exit(0) }
        DispatchQueue.global().asyncAfter(wallDeadline: .now() + duration + 20, execute: item)
        watchdog = item

        isEngaged = true
    }

    func release() {
        guard isEngaged else { return }

        watchdog?.cancel()
        watchdog = nil

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil

        NSApp.presentationOptions = []
        if pointerLocked {
            CGAssociateMouseAndMouseCursorPosition(1)
            NSCursor.unhide()
            pointerLocked = false
        }

        if sleepAssertion != 0 {
            IOPMAssertionRelease(sleepAssertion)
            sleepAssertion = 0
        }

        isEngaged = false
    }
}
