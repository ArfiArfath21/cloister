import AppKit
import SwiftUI

/// A small cream-on-ink switch, so toggles match the rest of the app.
private struct PaperToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack {
                configuration.label
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? Palette.paper : Palette.faint)
                    .frame(width: 34, height: 20)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(configuration.isOn ? Palette.ink : Palette.paper.opacity(0.7))
                            .frame(width: 14, height: 14)
                            .padding(3)
                    }
                    .animation(.easeOut(duration: 0.15), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RoundIconButton: View {
    let symbol: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Palette.paper.opacity(enabled ? 1 : 0.25))
                .frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(Palette.paper.opacity(enabled ? 0.35 : 0.1), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct SettingsView: View {
    @AppStorage(Pref.minutes) private var minutes = Pref.defaultMinutes
    @AppStorage(Pref.chime) private var chime = "Glass"
    @AppStorage(Pref.lockPointer) private var lockPointer = true
    @AppStorage(Pref.keepAwake) private var keepAwake = true
    @AppStorage(Pref.keepIntention) private var keepIntention = false

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                Text("SETTINGS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(6)
                    .foregroundStyle(Palette.muted)
                    .padding(.bottom, 26)

                duration
                    .padding(.bottom, 26)

                VStack(spacing: 0) {
                    row {
                        HStack {
                            label("Chime when done")
                            Spacer()
                            Picker("", selection: $chime) {
                                Text("None").tag("")
                                ForEach(Pref.chimes, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                    row { Toggle(isOn: $lockPointer) { label("Lock mouse and trackpad") }.toggleStyle(PaperToggleStyle()) }
                    row { Toggle(isOn: $keepAwake) { label("Keep display awake") }.toggleStyle(PaperToggleStyle()) }
                    row(last: true) { Toggle(isOn: $keepIntention) { label("Remember intention") }.toggleStyle(PaperToggleStyle()) }
                }

                Spacer(minLength: 16)

                Text("Settings can't be changed during a session.")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint.opacity(2))
            }
            .padding(.top, 40)
            .padding(.bottom, 22)
            .padding(.horizontal, 40)
        }
        .frame(width: 440, height: 470)
        .onChange(of: chime) { name in
            guard let sound = NSSound(named: name) else { return }
            sound.stop()
            sound.play()
        }
    }

    private var duration: some View {
        let index = Pref.minuteSteps.firstIndex(of: minutes)
            ?? Pref.minuteSteps.firstIndex { $0 > minutes } ?? Pref.minuteSteps.count - 1
        return HStack(spacing: 30) {
            RoundIconButton(symbol: "minus", enabled: index > 0) {
                minutes = Pref.minuteSteps[max(0, index - 1)]
            }
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.system(size: 64, weight: .ultraLight).monospacedDigit())
                    .foregroundStyle(Palette.paper)
                    .frame(minWidth: 110)
                Text(minutes == 1 ? "MINUTE" : "MINUTES")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(3)
                    .foregroundStyle(Palette.muted)
            }
            RoundIconButton(symbol: "plus", enabled: index < Pref.minuteSteps.count - 1) {
                minutes = Pref.minuteSteps[min(Pref.minuteSteps.count - 1, index + 1)]
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Palette.paper.opacity(0.9))
    }

    private func row<Content: View>(last: Bool = false, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content().frame(height: 46)
            if !last { Rectangle().fill(Palette.faint.opacity(0.6)).frame(height: 1) }
        }
    }
}
