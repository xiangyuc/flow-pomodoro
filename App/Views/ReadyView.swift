import FlowCore
import SwiftUI

struct ReadyView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let today = model.summary(for: .day)

        VStack(spacing: 16) {
            HStack(spacing: 2) {
                HeaderDetail(text: todayLine(today))
                Spacer()
                IconButton(systemName: "chart.bar", label: "Statistics", action: model.showStats)
                IconButton(systemName: "gearshape", label: "Settings") { model.screen = .settings }
                    .padding(.trailing, -6)
            }
            .frame(height: 28)

            RingDial(progress: 0, color: Theme.moss) {
                TimerReadout(time: DurationFormat.clock(model.engine.settings.minimumFocus), caption: "minimum")
            }

            if !model.parkedNote.isEmpty {
                NoteBlock(title: "Pick up from", note: model.parkedNote)
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button("Start focus", action: model.start)
                    .buttonStyle(.pill(.primary(Theme.moss)))
                    .keyboardShortcut(.space, modifiers: [])
                Text("Press Space to start")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private func todayLine(_ today: StatsSummary) -> String {
        guard today.sessionCount > 0 else { return "Today · no sessions yet" }
        let noun = today.sessionCount == 1 ? "session" : "sessions"
        return "Today · \(today.sessionCount) \(noun) · \(DurationFormat.short(today.totalFocused))"
    }
}
