import Foundation
import UserNotifications

protocol TimerCompletionNotifier {
    func requestAuthorization()
    func scheduleTimerCompletedAlert(in seconds: TimeInterval)
    func cancelTimerCompletedAlert()
}

struct SystemTimerCompletionNotifier: TimerCompletionNotifier {
    private let notificationIdentifier = "SneakyTimer.timerCompleted"

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func scheduleTimerCompletedAlert(in seconds: TimeInterval) {
        cancelTimerCompletedAlert()

        let triggerSeconds = max(1, seconds)
        let content = UNMutableNotificationContent()
        content.title = "SneakyTimer"
        content.body = "Time is up."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerSeconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelTimerCompletedAlert() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }
}
