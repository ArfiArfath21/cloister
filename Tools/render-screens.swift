// Renders the README screenshots offscreen, straight from the app's views.
//
//   swiftc -parse-as-library Sources/Session.swift Sources/Views.swift Sources/SettingsView.swift Tools/render-screens.swift -o build/render && build/render
import AppKit
import SwiftUI

@main
struct RenderScreens {
    static func main() {
        _ = NSApplication.shared
        Pref.register()
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().path

        let start = Session()
        start.trusted = true
        render(StartView(session: start, onBegin: {}, onGrant: {}, onSettings: {}),
               size: CGSize(width: 520, height: 420), to: "\(root)/docs/start.png")

        render(SettingsView(), size: CGSize(width: 440, height: 470), to: "\(root)/docs/settings.png")

        let locked = Session()
        locked.intention = "Draft chapter three"
        locked.begin(minutes: 25, at: Date().addingTimeInterval(-25 * 60 * 0.38))
        render(LockView(session: locked, primary: true, onReturn: {}),
               size: CGSize(width: 1440, height: 900), to: "\(root)/docs/lock.png")
    }

    static func render<V: View>(_ view: V, size: CGSize, to path: String) {
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        host.frame = CGRect(origin: .zero, size: size)
        window.contentView = host
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        host.layoutSubtreeIfNeeded()

        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: rep)
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
        window.orderOut(nil)
        print("Wrote \(path)")
    }
}
