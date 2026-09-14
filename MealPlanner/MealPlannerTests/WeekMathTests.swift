import Testing
import Foundation
@testable import MealPlanner

@MainActor
struct WeekMathTests {
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

    @Test func weekIDForMidWeekDate() throws {
        #expect(WeekMath.weekID(for: try date("2026-09-14 12:00"), calendar: calendar) == "2026-W38")
    }

    @Test func weekIDAndDayIndexForSunday() throws {
        let d = try date("2026-09-20 12:00")
        #expect(WeekMath.weekID(for: d, calendar: calendar) == "2026-W38")
        #expect(WeekMath.dayIndex(for: d, calendar: calendar) == 6)
    }

    @Test func weekIDAtYearBoundaryStaysInPreviousYearWeek53() throws {
        #expect(WeekMath.weekID(for: try date("2027-01-01 12:00"), calendar: calendar) == "2026-W53")
    }

    @Test func weekIDAtYearBoundaryEntersNewYearWeek01() throws {
        #expect(WeekMath.weekID(for: try date("2027-01-04 12:00"), calendar: calendar) == "2027-W01")
    }

    @Test func addingOneWeekAcrossYearBoundary() {
        #expect(WeekMath.weekID("2026-W53", adding: 1, calendar: calendar) == "2027-W01")
    }

    @Test func isEndedForAPastWeek() throws {
        #expect(WeekMath.isEnded("2026-W37", now: try date("2026-09-14 09:00"), calendar: calendar))
    }

    @Test func isEndedIsFalseUntilTheWeekIsOver() throws {
        #expect(!WeekMath.isEnded("2026-W38", now: try date("2026-09-20 23:59"), calendar: calendar))
    }

    @Test func isEndedBecomesTrueAtMondayMidnight() throws {
        #expect(WeekMath.isEnded("2026-W38", now: try date("2026-09-21 00:00"), calendar: calendar))
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

    @Test func titleForNextWeek() throws {
        let now = try date("2026-09-14 09:00")
        #expect(WeekMath.title(for: "2026-W39", now: now, calendar: calendar, locale: locale) == "Next week")
    }

    @Test func titleForThisAndLastWeek() throws {
        let now = try date("2026-09-14 09:00")
        #expect(WeekMath.title(for: "2026-W38", now: now, calendar: calendar, locale: locale) == "This week")
        #expect(WeekMath.title(for: "2026-W37", now: now, calendar: calendar, locale: locale) == "Last week")
    }

    @Test func titleForADistantWeekIncludesTheYear() throws {
        let now = try date("2026-09-14 09:00")
        #expect(WeekMath.title(for: "2026-W01", now: now, calendar: calendar, locale: locale) == "w/c 29 Dec 2025")
    }

    @Test func dateRangeTextWithinASingleMonth() {
        #expect(WeekMath.dateRangeText(for: "2026-W38", calendar: calendar, locale: locale) == "14–20 Sep")
    }

    @Test func dateRangeTextAcrossTwoMonths() {
        #expect(WeekMath.dateRangeText(for: "2026-W40", calendar: calendar, locale: locale) == "28 Sep – 4 Oct")
    }

    @Test func startDateIsMondayMidnight() throws {
        #expect(WeekMath.startDate(of: "2026-W38", calendar: calendar) == (try date("2026-09-14 00:00")))
    }

    @Test func weekCommencingTextOmitsTheYearForTheCurrentYear() {
        #expect(WeekMath.weekCommencingText(for: "2026-W38", calendar: calendar, locale: locale) == "w/c 14 Sep")
    }
}
