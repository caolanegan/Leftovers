import SwiftUI

/// One weekday's 3 `MealSlotRow`s (§10.1). The section-header dice ("Randomise
/// <Day>") arrives with the randomiser in M8.
struct DaySection: View {
    let weekID: String
    let dayIndex: Int
    let isToday: Bool
    let isReadOnly: Bool
    let plan: WeekPlan?
    let onSelect: (PlanPosition) -> Void
    let onRemove: (PlanPosition) -> Void

    /// A stable id for this day's header, distinct from its rows, so
    /// `ScrollViewReader` can scroll the header itself into view — scrolling
    /// to the section as a whole can leave the header hidden under the
    /// `WeekNavigator` safe-area inset.
    static func headerID(dayIndex: Int) -> String { "day-header-\(dayIndex)" }

    var body: some View {
        Section {
            ForEach(MealType.allCases.sorted()) { mealType in
                MealSlotRow(
                    dayName: fullDayName,
                    dayIndex: dayIndex,
                    mealType: mealType,
                    plan: plan,
                    isReadOnly: isReadOnly,
                    onTap: { onSelect(PlanPosition(weekID: weekID, dayIndex: dayIndex, mealType: mealType)) },
                    onRemove: { onRemove(PlanPosition(weekID: weekID, dayIndex: dayIndex, mealType: mealType)) }
                )
            }
        } header: {
            Text(headerText)
                .id(Self.headerID(dayIndex: dayIndex))
        }
    }

    private var date: Date? {
        WeekMath.date(dayIndex: dayIndex, in: weekID, calendar: WeekMath.appCalendar)
    }

    private var fullDayName: String {
        guard let date else { return "" }
        return formatted(date, format: "EEEE")
    }

    private var headerText: String {
        guard let date else { return "" }
        let base = formatted(date, format: "EEEE d MMM").uppercased()
        return isToday ? "\(base) · TODAY" : base
    }

    private func formatted(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = WeekMath.appCalendar
        formatter.timeZone = WeekMath.appCalendar.timeZone
        formatter.locale = .current
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
