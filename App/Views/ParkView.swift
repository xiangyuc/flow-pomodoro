import FlowCore
import SwiftUI

/// One line about where to pick up, so stopping costs less.
struct ParkView: View {
    @Environment(AppModel.self) private var model
    let parked: ParkedFocus
    @FocusState private var noteFocused: Bool

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Before you step away").font(.system(size: 13, weight: .semibold))
                Spacer()
                HeaderDetail(text: "\(DurationFormat.minutes(parked.record.focused)) min")
            }
            .frame(height: 28)

            VStack(alignment: .leading, spacing: 10) {
                Text("Where will you pick up?")
                    .font(.display(24))

                TextField("e.g. Fix the edge case in parser.swift", text: $model.draftNote)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(noteFocused ? Theme.moss : Theme.hairline, lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.mossTint, lineWidth: 3)
                            .padding(-2)
                            .opacity(noteFocused ? 1 : 0)
                    )
                    .focused($noteFocused)
                    .onSubmit { model.startBreak(savingNote: true) }

                Text("Shown when you come back. One line is enough.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(.top, 24)

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button("Start \(DurationFormat.minutes(parked.earnedBreak)) min break") {
                    model.startBreak(savingNote: true)
                }
                .buttonStyle(.pill(.primary(Theme.water)))

                Button("Skip note") { model.startBreak(savingNote: false) }
                    .buttonStyle(.pill(.quiet))
            }
        }
        .onAppear { noteFocused = true }
    }
}
