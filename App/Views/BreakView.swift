import FlowCore
import SwiftUI

struct BreakView: View {
    @Environment(AppModel.self) private var model
    let session: BreakSession

    var body: some View {
        let remaining = session.remaining(at: model.now)

        VStack(spacing: 16) {
            HStack {
                StateTitle(title: "Break", marker: .dot(Theme.water))
                Spacer()
                HeaderDetail(text: "earned by \(DurationFormat.minutes(session.focused)) min")
            }
            .frame(height: 28)

            RingDial(progress: remaining / max(1, session.length), color: Theme.water, texture: .water) {
                TimerReadout(time: DurationFormat.countdown(remaining), caption: "step outside")
            }

            if !model.parkedNote.isEmpty {
                NoteBlock(title: "Up next", note: model.parkedNote)
            }

            Spacer(minLength: 0)

            Button("End break early", action: model.endBreak)
                .buttonStyle(.pill(.secondary))
        }
    }
}
