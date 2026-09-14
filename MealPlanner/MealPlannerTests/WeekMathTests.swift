import Testing
import Foundation
@testable import MealPlanner

@MainActor
struct WeekMathTests {
    let calendar = WeekMath.appCalendar
    let locale = Locale(identifier: "en_GB")

    private func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text) ?? Date()
    }

    @Test func weekIDForMidWeekDate() {
        #expect(WeekMath.weekID(for: date("2026-09-14 12:00"), calendar: calendar) == "2026-W38")
    }

    @Test func weekIDAndDayIndexForSunday() {
        let d = date("2026-09-20 12:00")
        #expect(WeekMath.weekID(for: d, calendar: calendar) == "2026-W38")
        #expect(WeekMath.dayIndex(for: d, calendar: calendar) == 6)
    }

    @Test func weekIDAtYearBoundaryStaysInPreviousYearWeek53() {
        #expect(WeekMath.weekID(for: date("2027-01-01 12:00"), calendar: calendar) == "2026-W53")
    }

    @Test func weekIDAtYearBoundaryEntersNewYearWeek01() {
        #expect(WeekMath.weekID(for: date("2027-01-04 12:00"), calendar: calendar) == "2027-W01")
    }

    @Test func addingOneWeekAcrossYearBoundary() {
        #expect(WeekMath.weekID("2026-W53", adding: 1, calendar: calendar) == "2027-W01")
    }

    @Test func isEndedForAPastWeek() {
        #expect(WeekMath.isEnded("2026-W37", now: date("2026-09-14 09:00"), calendar: calendar))
    }

    @Test func isEndedIsFalseUntilTheWeekIsOver() {
        #expect(!WeekMath.isEnded("2026-W38", now: date("2026-09-20 23:59"), calendar: calendar))
    }

    @Test func isEndedBecomesTrueAtMondayMidnight() {
        #expect(WeekMath.isEnded("2026-W38", now: date("2026-09-21 00:00"), calendar: calendar))
    }

    @Test func dayDistanceAcrossAWeekBoundary() {
        let distance = WeekMath.dayDistance(from: ("2026-W38", 6), to: ("2026-W39", 0), calendar: calendar)
        #expect(distance == 1)
    }

    @Test func nextDayRollsIntoTheFollowingWeek() {
        let next = WeekMath.nextDay(weekID: "2026-W38", dayIndex: 6, calendar: calendar)
        #expect(next.weekID == "2026-W39")
        #expect(next.dayIndex == 0)
    }

    @Test func titleForNextWeek() {
        let now = date("2026-09-14 09:00")
        #expect(WeekMath.title(for: "2026-W39", now: now, calendar: calendar, locale: locale) == "Next week")
    }

    @Test func titleForThisAndLastWeek() {
        let now = date("2026-09-14 09:00")
        #expect(WeekMath.title(for: "2026-W38", now: now, calendar: calendar, locale: locale) == "This week")
        #expect(WeekMath.title(for: "2026-W37", now: now, calendar: calendar, locale: locale) == "Last week")
    }

    @Test func dateRangeTextWithinASingleMonth() {
        #expect(WeekMath.dateRangeText(for: "2026-W38", calendar: calendar, locale: locale) == "14–20 Sep")
    }

    @Test func dateRangeTextAcrossTwoMonths() {
        #expect(WeekMath.dateRangeText(for: "2026-W40", calendar: calendar, locale: locale) == "28 Sep – 4 Oct")
    }
}
