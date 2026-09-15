import SwiftUI
import SwiftData

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
    let onMarkAsLeftovers: (PlanPosition) -> Void
    let onMarkAsCooked: (PlanPosition) -> Void
    let onAddLeftovers: (_ from: PlanPosition, _ to: PlanPosition) -> Void

    @Environment(\.modelContext) private var modelContext

    /// A stable id for this day's header, distinct from its rows, so
    /// `ScrollViewReader` can scroll the header itself into view — scrolling
    /// to the section as a whole can leave the header hidden under the
    /// `WeekNavigator` safe-area inset.
    static func headerID(dayIndex: Int) -> String { "day-header-\(dayIndex)" }

    var body: some View {
        Section {
            ForEach(MealType.allCases.sorted()) { mealType in
                let position = PlanPosition(weekID: weekID, dayIndex: dayIndex, mealType: mealType)
                MealSlotRow(
                    dayName: fullDayName,
                    dayIndex: dayIndex,
                    mealType: mealType,
                    plan: plan,
                    isReadOnly: isReadOnly,
                    liveLeftoverSourceLabel: liveLeftoverSourceLabel(mealType),
                    canMarkAsLeftovers: hasLeftoverCandidate(mealType),
                    canLeftoversForTomorrowLunch: canOfferLeftoversForTomorrow(source: mealType, target: .lunch),
                    canLeftoversForTomorrowDinner: canOfferLeftoversForTomorrow(source: mealType, target: .dinner),
                    onTap: { onSelect(position) },
                    onRemove: { onRemove(position) },
                    onMarkAsLeftovers: { onMarkAsLeftovers(position) },
                    onMarkAsCooked: { onMarkAsCooked(position) },
                    onLeftoversForTomorrowLunch: { onAddLeftovers(position, tomorrowPosition(mealType: .lunch)) },
                    onLeftoversForTomorrowDinner: { onAddLeftovers(position, tomorrowPosition(mealType: .dinner)) }
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

    private func slot(_ mealType: MealType) -> MealSlot? {
        (plan?.slots ?? []).first { $0.dayIndex == dayIndex && $0.mealType == mealType }
    }

    private func tomorrowPosition(mealType: MealType) -> PlanPosition {
        let (nextWeekID, nextDayIndex) = WeekMath.nextDay(weekID: weekID, dayIndex: dayIndex, calendar: WeekMath.appCalendar)
        return PlanPosition(weekID: nextWeekID, dayIndex: nextDayIndex, mealType: mealType)
    }

    private func liveLeftoverSourceLabel(_ mealType: MealType) -> String? {
        guard !isReadOnly, let slot = slot(mealType), slot.isLeftovers else { return nil }
        return try? WeekPlanService(context: modelContext).sourceLabel(for: slot)
    }

    private func hasLeftoverCandidate(_ mealType: MealType) -> Bool {
        guard !isReadOnly, let slot = slot(mealType), !slot.isLeftovers, let mealID = slot.meal?.id else { return false }
        let position = PlanPosition(weekID: weekID, dayIndex: dayIndex, mealType: mealType)
        let candidates = try? WeekPlanService(context: modelContext).leftoverSourceCandidates(mealID: mealID, target: position)
        return !(candidates ?? []).isEmpty
    }

    private func canOfferLeftoversForTomorrow(source sourceType: MealType, target targetType: MealType) -> Bool {
        guard !isReadOnly, let sourceSlot = slot(sourceType), !sourceSlot.isLeftovers, sourceSlot.meal != nil else { return false }
        let target = tomorrowPosition(mealType: targetType)
        return (try? WeekPlanService(context: modelContext).isEmptyAndEditable(target)) ?? false
    }
}
