import AppKit
import SwiftUI

/// Borderless windows refuse key status by default; shields need it.
final class ShieldWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let session = Session()
    private let lockdown = Lockdown()
    private var startWindow: NSWindow!
    private var settingsWindow: NSWindow?
    private var shields: [NSWindow] = []
    private var ticker: Timer?
    private var trustPoll: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Pref.register()
        buildMenu()

        startWindow = makePanel(size: NSSize(width: 520, height: 420), rootView: StartView(
            session: session,
            onBegin: { [weak self] in self?.begin() },
            onGrant: { [weak self] in self?.requestAccess() },
            onSettings: { [weak self] in self?.openSettings() }
        ))
        startWindow.center()
        startWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        trustPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let trusted = AXIsProcessTrusted()
            if self.session.trusted != trusted { self.session.trusted = trusted }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.session.phase == .locked else { return }
            self.raiseShields()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        lockdown.isEngaged ? .terminateCancel : .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: - Session flow

    private func begin() {
        guard session.phase == .idle else { return }
        guard AXIsProcessTrusted() else { requestAccess(); return }

        let defaults = UserDefaults.standard
        let minutes = Pref.sessionMinutes
        do {
            try lockdown.engage(
                for: TimeInterval(minutes * 60),
                lockPointer: defaults.bool(forKey: Pref.lockPointer),
                keepAwake: defaults.bool(forKey: Pref.keepAwake)
            )
        } catch {
            session.error = "Couldn't take hold of input. Re-grant Accessibility and try again."
            return
        }

        session.begin(minutes: minutes)
        settingsWindow?.close()
        startWindow.orderOut(nil)
        raiseShields()

        let ticker = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, Date() >= self.session.end else { return }
            self.finish()
        }
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    private func finish() {
        ticker?.invalidate()
        ticker = nil
        lockdown.release()
        session.phase = .done
        if let chime = UserDefaults.standard.string(forKey: Pref.chime), !chime.isEmpty {
            NSSound(named: chime)?.play()
        }

        // Keep only the main screen's shield, now showing the way out.
        for shield in shields.dropFirst() { shield.close() }
        shields = Array(shields.prefix(1))
        shields.first?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func returnToStart() {
        session.phase = .idle
        if !UserDefaults.standard.bool(forKey: Pref.keepIntention) { session.intention = "" }
        // Show the start window before closing shields so the app never
        // runs out of windows and quits.
        startWindow.makeKeyAndOrderFront(nil)
        for shield in shields { shield.close() }
        shields = []
        NSApp.activate(ignoringOtherApps: true)
    }

    /// One shield per display, above everything, on every Space.
    private func raiseShields() {
        for shield in shields { shield.close() }
        shields = NSScreen.screens.enumerated().map { index, screen in
            let window = ShieldWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.setFrame(screen.frame, display: true)
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            window.backgroundColor = NSColor(Palette.ink)
            window.isOpaque = true
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = NSHostingView(rootView: LockView(
                session: session,
                primary: index == 0,
                onReturn: { [weak self] in self?.returnToStart() }
            ))
            window.orderFrontRegardless()
            return window
        }
        shields.first?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Windows and menu

    @objc private func openSettings() {
        guard session.phase == .idle else { return }
        if settingsWindow == nil {
            let window = makePanel(size: NSSize(width: 440, height: 470), rootView: SettingsView())
            window.title = "Settings"
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makePanel<V: View>(size: NSSize, rootView: V) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(Palette.ink)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: rootView)
        return window
    }

    private func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        session.trusted = AXIsProcessTrustedWithOptions(options)
    }

    private func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Cloister", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settings = appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Cloister", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Cloister", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = main
    }
}
