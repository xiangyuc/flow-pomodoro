import FlowCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Chevron and title are one back button, flush with the rows' left edge.
                Button { model.screen = .timer } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkSecondary)
                        Text("Settings")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    .frame(height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Back")

                Spacer()

                Button("Quit", action: model.quit)
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(height: 28)
                    .contentShape(Rectangle())
                    .help("Quit Flow Pomodoro (⌘Q)")
            }
            .frame(height: 28)

            VStack(spacing: 0) {
                row("Minimum focus") {
                    valueMenu("Minimum focus", selection: $model.minimumMinutes, options: [15, 20, 25, 30]) { "\($0) min" }
                }
                row("Break") {
                    valueMenu("Break", selection: $model.breakRatio, options: [4, 5, 6]) { "1 per \($0) min" }
                }
                row("Ceiling") {
                    valueMenu("Ceiling", selection: $model.ceilingMinutes, options: [60, 90, 120]) { "\($0) min" }
                }
                row("Chime at minimum") {
                    toggle("Chime at minimum", isOn: $model.chimeEnabled)
                }
                row("Open at login", divider: false) {
                    toggle("Open at login", isOn: $model.openAtLogin)
                }
            }
            .font(.system(size: 13))

            Spacer(minLength: 0)

            Text(footer)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: String {
        let settings = model.engine.settings
        let minimum = settings.minimumFocus
        let first = DurationFormat.minutes(settings.earnedBreak(for: minimum))
        let second = DurationFormat.minutes(settings.earnedBreak(for: minimum * 2))
        return "Breaks scale with focus time: \(DurationFormat.minutes(minimum)) min earns \(first), "
            + "\(DurationFormat.minutes(minimum * 2)) min earns \(second)."
    }

    /// Label on the left, control on the right, hairline below.
    private func row<Control: View>(
        _ label: String,
        divider: Bool = true,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            control()
        }
        .frame(height: 44)
        .overlay(alignment: .bottom) {
            if divider {
                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
        }
    }

    /// A plain value with a small chevron that opens a checkmarked menu.
    private func valueMenu(
        _ title: String,
        selection: Binding<Int>,
        options: [Int],
        label: @escaping (Int) -> String
    ) -> some View {
        Menu {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Text(label(selection.wrappedValue))
                .font(.system(size: 13))
                .monospacedDigit()
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .foregroundStyle(Theme.ink)
        .fixedSize()
        .accessibilityLabel(title)
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Theme.moss)
    }
}
