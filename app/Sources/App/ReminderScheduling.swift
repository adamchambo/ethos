import Foundation
import UserNotifications

enum ReminderScheduling {
    nonisolated static func reschedule(reminders: [Reminder], habits: [Habit]) {
        let center = UNUserNotificationCenter.current()
        let enabled = reminders.filter(\.isEnabled)
        guard !enabled.isEmpty else {
            center.removeAllPendingNotificationRequests()
            return
        }

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            center.removeAllPendingNotificationRequests()
            guard granted else { return }

            for reminder in enabled {
                guard let habit = habits.first(where: { $0.id == reminder.habitID }),
                      habit.lifecycle == .active
                else { continue }
                schedule(reminder, habit: habit, center: center)
            }
        }
    }

    nonisolated static func requestAccess() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    nonisolated static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private nonisolated static func schedule(_ reminder: Reminder, habit: Habit, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = habit.title
        content.body = habit.direction == .quit ? "Stay with it." : "Time to log it."
        content.sound = .default

        var components = DateComponents()
        components.hour = reminder.time.hour
        components.minute = reminder.time.minute

        if reminder.weekdays.isEmpty {
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
            center.add(request)
            return
        }

        for weekday in reminder.weekdays {
            components.weekday = weekday.foundationIndex
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(reminder.id.uuidString)-\(weekday.rawValue)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}
