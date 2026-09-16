import Foundation
import UserNotifications

protocol NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func scheduleWeeklyReminder(weekday: Int, hour: Int, minute: Int) async throws
    func cancelWeeklyReminder()
}

/// §11: the weekly "time to plan your meals" reminder.
struct NotificationScheduler: NotificationScheduling {
    static let reminderIdentifier = "weekly-shopping-reminder"

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func scheduleWeeklyReminder(weekday: Int, hour: Int, minute: Int) async throws {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Time to plan your meals"
        content.body = "Pick this week's meals and your shopping list will build itself."
        content.sound = .default

        let request = UNNotificationRequest(identifier: Self.reminderIdentifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    func cancelWeeklyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])
    }

    /// Pure §11.3 footer helper — the next date the weekly reminder would
    /// fire, e.g. for "weekday: 1 (Sunday), minutes: 1080 (18:00)" the next
    /// Sunday at 18:00 after `date`.
    static func nextReminderDate(weekday: Int, minutes: Int, after date: Date, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = minutes / 60
        components.minute = minutes % 60
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents)
    }

    /// §11.3's footer copy, e.g. "Next reminder: Sunday 20 Sep at 18:00".
    static func footerText(weekday: Int, minutes: Int, now: Date, calendar: Calendar, locale: Locale) -> String {
        guard let next = nextReminderDate(weekday: weekday, minutes: minutes, after: now, calendar: calendar) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = "EEEE d MMM 'at' HH:mm"
        return "Next reminder: \(formatter.string(from: next))"
    }
}
