import SwiftUI

enum Palette {
    static let ink = Color(red: 0.051, green: 0.051, blue: 0.059)
    static let paper = Color(red: 0.925, green: 0.894, blue: 0.835)
    static let muted = Color.white.opacity(0.42)
    static let faint = Color.white.opacity(0.14)
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            Palette.ink
            RadialGradient(
                colors: [Palette.paper.opacity(0.07), .clear],
                center: .center, startRadius: 0, endRadius: 720
            )
        }
        .ignoresSafeArea()
    }
}

private struct PillButton: View {
    let title: String
    var filled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(filled ? Palette.ink : Palette.paper)
                .frame(minWidth: 148, minHeight: 40)
                .padding(.horizontal, filled ? 0 : 18)
                .background(Capsule().fill(filled ? Palette.paper : .clear))
                .overlay(Capsule().strokeBorder(Palette.paper.opacity(filled ? 0 : 0.5), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Start

struct StartView: View {
    @ObservedObject var session: Session
    let onBegin: () -> Void
    let onGrant: () -> Void
    let onSettings: () -> Void
    @AppStorage(Pref.minutes) private var minutes = Pref.defaultMinutes
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                Text("CLOISTER")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(6)
                    .foregroundStyle(Palette.muted)

                Spacer()

                VStack(spacing: 14) {
                    // macOS left-aligns a TextField's own prompt, so draw a centred one.
                    ZStack {
                        if session.intention.isEmpty {
                            Text("What deserves your full attention?")
                                .foregroundStyle(Palette.faint.opacity(2))
                                .allowsHitTesting(false)
                        }
                        TextField("", text: $session.intention)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Palette.paper)
                            .focused($focused)
                            .onSubmit(onBegin)
                    }
                    .font(.system(size: 22, weight: .light))

                    Rectangle().fill(Palette.faint).frame(width: 280, height: 1)
                }

                Spacer()

                if session.trusted {
                    PillButton(title: "Begin", action: onBegin)
                    Button(action: onSettings) {
                        Text("\(minutes) min")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Change in Settings (⌘,)")
                    .padding(.top, 14)
                } else {
                    PillButton(title: "Allow input lock", filled: false, action: onGrant)
                    Text("Cloister needs Accessibility access to hold the keyboard and mouse.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                }

                if let error = session.error {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.93, green: 0.55, blue: 0.5))
                        .padding(.top, 8)
                }
            }
            .padding(.top, 40)
            .padding(.bottom, 36)
            .padding(.horizontal, 48)
        }
        .frame(width: 520, height: 420)
        .onAppear { focused = true }
    }
}

// MARK: - Lock

struct LockView: View {
    @ObservedObject var session: Session
    let primary: Bool
    let onReturn: () -> Void

    private let diameter: CGFloat = 380

    var body: some View {
        ZStack {
            Backdrop()
            TimelineView(.animation(paused: session.phase != .locked)) { context in
                let done = session.phase == .done
                let progress = done ? 1 : session.progress(at: context.date)

                VStack(spacing: 44) {
                    ZStack {
                        ring(progress)

                        VStack(spacing: 12) {
                            Text(done ? "Done" : clock(session.remaining(at: context.date)))
                                .font(.system(size: done ? 72 : 96, weight: .ultraLight).monospacedDigit())
                                .foregroundStyle(Palette.paper)

                            Group {
                                if done {
                                    Text("time well spent")
                                } else {
                                    Text("until \(Text(session.end, style: .time))")
                                }
                            }
                            .font(.system(size: 11, weight: .medium))
                            .tracking(3)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.muted)
                        }
                    }
                    .frame(width: diameter, height: diameter)

                    if !session.intention.isEmpty {
                        Text(session.intention)
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 560)
                    }

                    if done && primary {
                        PillButton(title: "Return", action: onReturn)
                            .keyboardShortcut(.defaultAction)
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.6), value: done)
            }
        }
    }

    private func ring(_ progress: Double) -> some View {
        let radius = diameter / 2
        let angle = progress * 2 * .pi - .pi / 2
        return ZStack {
            Circle().stroke(Palette.faint, lineWidth: 1.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Palette.paper, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(Palette.paper)
                .frame(width: 7, height: 7)
                .shadow(color: Palette.paper.opacity(0.6), radius: 6)
                .offset(x: radius * cos(angle), y: radius * sin(angle))
        }
    }

    private func clock(_ remaining: TimeInterval) -> String {
        let seconds = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
