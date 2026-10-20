import AppKit
import SwiftUI

/// Opens the stats page in its own small window. Done in AppKit because a menu bar app
/// has no main window, and a SwiftUI `Window` scene may open by itself at launch.
@MainActor
final class StatsWindowController {
    private var window: NSWindow?

    func show(model: AppModel) {
        if window == nil {
            let hosting = NSHostingController(rootView: StatsView().environment(model))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Stats"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.titlebarAppearsTransparent = true
            window.backgroundColor = Theme.groundNSColor
            window.appearance = NSAppearance(named: .aqua)
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
