import Foundation

enum WeekMath {
    static var appCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        calendar.firstWeekday = 2            // Monday
        calendar.minimumDaysInFirstWeek = 4  // ISO 8601: week 1 contains the year's first Thursday
        return calendar
    }

    static func weekID(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let year = components.yearForWeekOfYear, let week = components.weekOfYear else {
            return ""
        }
        return String(format: "%04d-W%02d", year, week)
    }

    static func startDate(of weekID: String, calendar: Calendar) -> Date? {
        guard let (year, week) = parse(weekID) else { return nil }
        var components = DateComponents()
        components.yearForWeekOfYear = year
        components.weekOfYear = week
        components.weekday = calendar.firstWeekday
        guard let date = calendar.date(from: components) else { return nil }
        return calendar.startOfDay(for: date)
    }

    static func weekID(_ weekID: String, adding weeks: Int, calendar: Calendar) -> String {
        guard let start = startDate(of: weekID, calendar: calendar),
              let newDate = calendar.date(byAdding: .day, value: weeks * 7, to: start)
        else { return weekID }
        return Self.weekID(for: newDate, calendar: calendar)
    }

    static func date(dayIndex: Int, in weekID: String, calendar: Calendar) -> Date? {
        guard let start = startDate(of: weekID, calendar: calendar) else { return nil }
        return calendar.date(byAdding: .day, value: dayIndex, to: start)
    }

    static func dayIndex(for date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)  // 1 = Sunday … 7 = Saturday
        return (weekday + 5) % 7                                // 0 = Monday … 6 = Sunday
    }

    static func isEnded(_ weekID: String, now: Date, calendar: Calendar) -> Bool {
        let current = Self.weekID(for: now, calendar: calendar)
        return compare(weekID, current) == .orderedAscending
    }

    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        if a == b { return .orderedSame }
        return a < b ? .orderedAscending : .orderedDescending
    }

    static func dayDistance(
        from: (weekID: String, dayIndex: Int),
        to: (weekID: String, dayIndex: Int),
        calendar: Calendar
    ) -> Int {
        guard let fromDate = date(dayIndex: from.dayIndex, in: from.weekID, calendar: calendar),
              let toDate = date(dayIndex: to.dayIndex, in: to.weekID, calendar: calendar)
        else { return 0 }
        return calendar.dateComponents([.day], from: fromDate, to: toDate).day ?? 0
    }

    static func nextDay(weekID: String, dayIndex: Int, calendar: Calendar) -> (weekID: String, dayIndex: Int) {
        if dayIndex < 6 {
            return (weekID, dayIndex + 1)
        }
        return (Self.weekID(weekID, adding: 1, calendar: calendar), 0)
    }

    static func shortDayName(_ dayIndex: Int) -> String {
        let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        guard names.indices.contains(dayIndex) else { return "" }
        return names[dayIndex]
    }

    static func title(for weekID: String, now: Date, calendar: Calendar, locale: Locale) -> String {
        let current = Self.weekID(for: now, calendar: calendar)
        if weekID == current { return "This week" }
        if weekID == Self.weekID(current, adding: 1, calendar: calendar) { return "Next week" }
        if weekID == Self.weekID(current, adding: -1, calendar: calendar) { return "Last week" }

        let currentYear = calendar.component(.year, from: now)
        let weekYear = startDate(of: weekID, calendar: calendar).map { calendar.component(.year, from: $0) }
        let includeYear = weekYear != currentYear
        return weekCommencingText(for: weekID, calendar: calendar, locale: locale, includeYear: includeYear)
    }

    static func dateRangeText(for weekID: String, calendar: Calendar, locale: Locale) -> String {
        guard let start = startDate(of: weekID, calendar: calendar),
              let end = calendar.date(byAdding: .day, value: 6, to: start)
        else { return "" }

        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)
        let startYear = calendar.component(.year, from: start)
        let endYear = calendar.component(.year, from: end)

        let dayFormatter = dateFormatter(format: "d", calendar: calendar, locale: locale)
        let dayMonthFormatter = dateFormatter(format: "d MMM", calendar: calendar, locale: locale)

        if startMonth == endMonth, startYear == endYear {
            return "\(dayFormatter.string(from: start))–\(dayMonthFormatter.string(from: end))"
        }
        return "\(dayMonthFormatter.string(from: start)) – \(dayMonthFormatter.string(from: end))"
    }

    static func weekCommencingText(for weekID: String, calendar: Calendar, locale: Locale) -> String {
        weekCommencingText(for: weekID, calendar: calendar, locale: locale, includeYear: false)
    }

    // MARK: - Private helpers

    private static func weekCommencingText(
        for weekID: String, calendar: Calendar, locale: Locale, includeYear: Bool
    ) -> String {
        guard let start = startDate(of: weekID, calendar: calendar) else { return "" }
        let formatter = dateFormatter(format: includeYear ? "d MMM yyyy" : "d MMM", calendar: calendar, locale: locale)
        return "w/c \(formatter.string(from: start))"
    }

    private static func dateFormatter(format: String, calendar: Calendar, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter
    }

    private static func parse(_ weekID: String) -> (year: Int, week: Int)? {
        let parts = weekID.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), parts[1].hasPrefix("W"),
              let week = Int(parts[1].dropFirst())
        else { return nil }
        return (year, week)
    }
}
