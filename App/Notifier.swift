import FlowCore
import UserNotifications

/// The few real notifications: the 90-minute ceiling, the end of a wrap-up, and the end of a break.
/// The 25-minute minimum deliberately never posts one.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    enum Action {
        case takeBreak
        case snooze
        case startBreak
    }

    var onAction: ((Action) -> Void)?

    private let center = UNUserNotificationCenter.current()

    private enum ID {
        static let ceiling = "ceiling"
        static let wrapUp = "wrapUp"
        static let breakEnded = "breakEnded"
        static let takeBreak = "takeBreak"
        static let snooze = "snooze"
        static let startBreak = "startBreak"
    }

    override init() {
        super.init()
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: ID.ceiling,
                actions: [
                    UNNotificationAction(identifier: ID.takeBreak, title: "Take break"),
                    UNNotificationAction(identifier: ID.snooze, title: "10 more min")
                ],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: ID.wrapUp,
                actions: [UNNotificationAction(identifier: ID.startBreak, title: "Start break")],
                intentIdentifiers: []
            )
        ])
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postCeilingNudge(focused: TimeInterval, earnedBreak: TimeInterval) {
        post(
            id: ID.ceiling,
            title: "\(DurationFormat.minutes(focused)) minutes in",
            body: "A long, good stretch. Your \(DurationFormat.minutes(earnedBreak)) min break is ready.",
            category: ID.ceiling
        )
    }

    func postWrapUpEnded(earnedBreak: TimeInterval) {
        post(
            id: ID.wrapUp,
            title: "Time to wrap up",
            body: "Park a note and take your \(DurationFormat.minutes(earnedBreak)) min break.",
            category: ID.wrapUp
        )
    }

    func postBreakEnded(note: String) {
        post(
            id: ID.breakEnded,
            title: "Break's over",
            body: note.isEmpty ? "Ready when you are." : "Up next: \(note)",
            category: nil
        )
    }

    func clearCeilingNudge() {
        center.removeDeliveredNotifications(withIdentifiers: [ID.ceiling])
    }

    private func post(id: String, title: String, body: String, category: String?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let category { content.categoryIdentifier = category }
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action: Action?
        switch response.actionIdentifier {
        case ID.takeBreak: action = .takeBreak
        case ID.snooze: action = .snooze
        case ID.startBreak: action = .startBreak
        default: action = nil
        }
        if let action {
            Task { @MainActor in self.onAction?(action) }
        }
        completionHandler()
    }
}
