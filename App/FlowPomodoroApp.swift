import SwiftUI

@main
struct FlowPomodoroApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar item: a small monochrome icon plus the time, drawn as one image
/// so the digits keep a fixed width.
struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        let state = model.menuBarState
        Image(nsImage: MenuBarIcon.image(for: state.icon, text: state.text))
            .accessibilityLabel(state.text.map { "Flow Pomodoro, \($0)" } ?? "Flow Pomodoro")
    }
}
