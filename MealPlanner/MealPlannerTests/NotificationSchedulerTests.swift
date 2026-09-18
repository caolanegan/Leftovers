import Testing
import Foundation
@testable import Leftovers

@MainActor
struct NotificationSchedulerTests {
    let calendar = WeekMath.appCalendar
    let locale = Locale(identifier: "en_GB")

    private func date(_ text: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return try #require(formatter.date(from: text))
    }

    @Test func reminderIdentifierIsStable() {
        #expect(NotificationScheduler.reminderIdentifier == "weekly-shopping-reminder")
    }

    @Test func nextReminderDateFindsTheUpcomingWeekday() throws {
        let now = try date("2026-09-14 12:00")  // Monday
        let next = NotificationScheduler.nextReminderDate(weekday: 1, minutes: 1080, after: now, calendar: calendar)
        #expect(next == (try date("2026-09-20 18:00")))  // next Sunday at 18:00
    }

    @Test func nextReminderDateRollsToNextWeekWhenTodaysTimeHasPassed() throws {
        let now = try date("2026-09-20 19:00")  // Sunday evening, after 18:00
        let next = NotificationScheduler.nextReminderDate(weekday: 1, minutes: 1080, after: now, calendar: calendar)
        #expect(next == (try date("2026-09-27 18:00")))
    }

    @Test func footerTextMatchesTheSpecExample() throws {
        let now = try date("2026-09-14 12:00")
        let text = NotificationScheduler.footerText(weekday: 1, minutes: 1080, now: now, calendar: calendar, locale: locale)
        #expect(text == "Next reminder: Sunday 20 Sep at 18:00")
    }

    @Test func footerTextUsesTheGivenLocalesHourCycle() throws {
        let now = try date("2026-09-14 12:00")
        let text = NotificationScheduler.footerText(
            weekday: 1, minutes: 1080, now: now, calendar: calendar, locale: Locale(identifier: "en_US")
        )
        #expect(text == "Next reminder: Sunday 20 Sep at 6:00\u{202F}PM")  // narrow no-break space before AM/PM
    }
}
