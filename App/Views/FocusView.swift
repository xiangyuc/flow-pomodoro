import FlowCore
import SwiftUI

/// The first stretch, counting down to the minimum.
struct FocusView: View {
    @Environment(AppModel.self) private var model
    let session: FocusSession

    var body: some View {
        let minimum = model.engine.settings.minimumFocus
        let remaining = max(0, minimum - session.elapsed(at: model.now))

        VStack(spacing: 16) {
            HStack {
                StateTitle(title: "Focus", marker: .dot(Theme.moss))
                Spacer()
                HeaderDetail(text: "Session \(model.summary(for: .day).sessionCount + 1)")
            }
            .frame(height: 28)

            RingDial(progress: remaining / minimum, color: Theme.moss) {
                TimerReadout(
                    time: DurationFormat.countdown(remaining),
                    caption: session.isPaused ? "paused" : "to minimum"
                )
            }

            if !model.activeNote.isEmpty {
                NoteBlock(title: "Working on", note: model.activeNote)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if session.isPaused {
                    Button("Resume", action: model.resume)
                        .buttonStyle(.pill(.primary(Theme.moss)))
                        .keyboardShortcut(.space, modifiers: [])
                } else {
                    Button("Pause", action: model.pause)
                        .buttonStyle(.pill(.secondary))
                        .keyboardShortcut(.space, modifiers: [])
                }
                Button("End", action: model.end)
                    .buttonStyle(.pill(.quiet))
            }
        }
    }
}
