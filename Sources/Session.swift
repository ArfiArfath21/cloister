import Foundation
import ApplicationServices

/// User preferences, stored in UserDefaults and edited in the Settings window.
enum Pref {
    static let minutes = "sessionMinutes"
    static let chime = "chimeSound"            // "" plays nothing
    static let lockPointer = "lockPointer"
    static let keepAwake = "keepDisplayAwake"
    static let keepIntention = "keepIntention"

    static let defaultMinutes = 25
    static let minuteSteps = [1, 5, 10, 15, 20, 25, 30, 40, 45, 50, 60, 75, 90, 120]
    static let chimes = ["Glass", "Hero", "Ping", "Purr", "Submarine", "Tink"]

    static func register() {
        UserDefaults.standard.register(defaults: [
            minutes: defaultMinutes,
            chime: "Glass",
            lockPointer: true,
            keepAwake: true,
            keepIntention: false,
        ])
    }

    static var sessionMinutes: Int {
        let value = UserDefaults.standard.integer(forKey: minutes)
        return value > 0 ? value : defaultMinutes
    }
}

final class Session: ObservableObject {
    enum Phase { case idle, locked, done }

    @Published var phase: Phase = .idle
    @Published var intention = ""
    @Published var trusted = AXIsProcessTrusted()
    @Published var error: String?

    private(set) var start = Date()
    private(set) var end = Date()
    private(set) var duration: TimeInterval = TimeInterval(Pref.defaultMinutes * 60)

    func begin(minutes: Int, at date: Date = Date()) {
        duration = TimeInterval(minutes * 60)
        start = date
        end = date.addingTimeInterval(duration)
        error = nil
        phase = .locked
    }

    func progress(at date: Date) -> Double {
        min(1, max(0, date.timeIntervalSince(start) / duration))
    }

    func remaining(at date: Date) -> TimeInterval {
        max(0, end.timeIntervalSince(date))
    }
}
