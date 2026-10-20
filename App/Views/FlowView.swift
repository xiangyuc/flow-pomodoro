import FlowCore
import SwiftUI

/// Past the minimum. The inner ring is full; the outer ring grows toward the ceiling.
struct FlowView: View {
    @Environment(AppModel.self) private var model
    let session: FocusSession

    var body: some View {
        let settings = model.engine.settings
        let elapsed = session.elapsed(at: model.now)
        let pastMinimum = max(0, elapsed - settings.minimumFocus)
        let flowSpan = max(1, settings.ceiling - settings.minimumFocus)
        let toCeiling = settings.ceiling - elapsed

        VStack(spacing: 16) {
            HStack {
                StateTitle(title: "In flow", marker: .leaf)
                Spacer()
                HeaderDetail(text: "+\(DurationFormat.clock(pastMinimum)) past \(DurationFormat.minutes(settings.minimumFocus))")
            }
            .frame(height: 28)

            RingDial(progress: 1, color: Theme.moss, outerProgress: pastMinimum / flowSpan) {
                TimerReadout(time: DurationFormat.clock(elapsed), caption: "focused")
            }

            VStack(spacing: 10) {
                InfoRow(
                    label: "Break earned",
                    value: "\(DurationFormat.minutes(settings.earnedBreak(for: elapsed))) min",
                    emphasized: true
                )
                if let deadline = session.wrapUpDeadline {
                    InfoRow(label: "Wrapping up", value: "\(DurationFormat.countdown(deadline.timeIntervalSince(model.now))) left")
                } else if toCeiling > 0 {
                    InfoRow(
                        label: "Outer ring fills at \(DurationFormat.minutes(settings.ceiling)) min",
                        value: "\(Int((toCeiling / 60).rounded(.up))) min left"
                    )
                } else {
                    InfoRow(label: "Past your \(DurationFormat.minutes(settings.ceiling)) min ceiling", value: "time to rest")
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button("Take break", action: model.takeBreak)
                    .buttonStyle(.pill(.primary(Theme.moss)))
                if !session.isWrappingUp {
                    Button("Wrap up · \(DurationFormat.minutes(settings.wrapUpLength))", action: model.wrapUp)
                        .buttonStyle(.pill(.secondary))
                }
            }
        }
    }
}
