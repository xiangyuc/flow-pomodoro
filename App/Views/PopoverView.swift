import FlowCore
import SwiftUI

/// The 300 × 400 panel under the menu bar icon. One screen per phase.
struct PopoverView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        content
            .padding(EdgeInsets(top: 20, leading: 24, bottom: 24, trailing: 24))
            .frame(width: 300, height: 400, alignment: .top)
            .background(Theme.ground)
            .foregroundStyle(Theme.ink)
            .environment(\.colorScheme, .light)
            .background {
                // ⌘Q from any screen. A menu bar app has no menu to carry the shortcut.
                Button("Quit Flow Pomodoro", action: model.quit)
                    .keyboardShortcut("q")
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
    }

    @ViewBuilder
    private var content: some View {
        if model.screen == .settings {
            SettingsView()
        } else {
            switch model.engine.phase {
            case .idle:
                ReadyView()
            case .focusing(let session):
                if session.elapsed(at: model.now) < model.engine.settings.minimumFocus {
                    FocusView(session: session)
                } else {
                    FlowView(session: session)
                }
            case .parking(let parked):
                ParkView(parked: parked)
            case .onBreak(let breakSession):
                BreakView(session: breakSession)
            }
        }
    }
}
