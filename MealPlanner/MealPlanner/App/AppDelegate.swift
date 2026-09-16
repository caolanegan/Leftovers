import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    let appState = AppState()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
}

/// §11.4.
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier == NotificationScheduler.reminderIdentifier else { return }

        let calendar = WeekMath.appCalendar
        let now = Date.now
        let currentWeekID = WeekMath.weekID(for: now, calendar: calendar)
        let dayIndex = WeekMath.dayIndex(for: now, calendar: calendar)  // 0 = Monday … 6 = Sunday

        appState.selectedTab = .plan
        appState.selectedWeekID = dayIndex >= 4
            ? WeekMath.weekID(currentWeekID, adding: 1, calendar: calendar)
            : currentWeekID
    }
}
