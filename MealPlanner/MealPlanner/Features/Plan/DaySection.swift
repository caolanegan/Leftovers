import SwiftUI

/// One weekday's 3 `MealSlotRow`s (§10.1).
struct DaySection: View {
    let weekID: String
    let dayIndex: Int
    let isToday: Bool
    let isReadOnly: Bool
    let plan: WeekPlan?
    /// Precomputed once per render by `WeekPlanContentView` — this view never
    /// issues its own `WeekPlanService` fetches (§10.1 perf: was up to 3 per row).
    let context: PlanWeekContext
    let onSelect: (PlanPosition) -> Void
    let onRemove: (PlanPosition) -> Void
    let onShuffle: (PlanPosition) -> Void
    let onMarkAsLeftovers: (PlanPosition) -> Void
    let onMarkAsCooked: (PlanPosition) -> Void
    let onAddLeftovers: (_ from: PlanPosition, _ to: PlanPosition) -> Void
    let onRandomizeDay: (Int) -> Void

    /// A stable id for this day's header, distinct from its rows, so
    /// `ScrollViewReader` can scroll the header itself into view — scrolling
    /// to the section as a whole can leave the header hidden under the
    /// `WeekNavigator` safe-area inset.
    static func headerID(dayIndex: Int) -> String { "day-header-\(dayIndex)" }

    var body: some View {
        Section {
            ForEach(MealType.allCases.sorted()) { mealType in
                let position = PlanPosition(weekID: weekID, dayIndex: dayIndex, mealType: mealType)
                let flags = menuFlags(mealType, position: position)
                MealSlotRow(
                    dayName: fullDayName,
                    dayIndex: dayIndex,
                    mealType: mealType,
                    plan: plan,
                    isReadOnly: isReadOnly,
                    liveLeftoverSourceLabel: liveLeftoverSourceLabel(mealType),
                    canMarkAsLeftovers: flags.canMarkAsLeftovers,
                    canLeftoversForTomorrowLunch: flags.leftoversForTomorrowLunch,
                    canLeftoversForTomorrowDinner: flags.leftoversForTomorrowDinner,
                    onTap: { onSelect(position) },
                    onRemove: { onRemove(position) },
                    onShuffle: { onShuffle(position) },
                    onMarkAsLeftovers: { onMarkAsLeftovers(position) },
                    onMarkAsCooked: { onMarkAsCooked(position) },
                    onLeftoversForTomorrowLunch: { onAddLeftovers(position, tomorrowPosition(mealType: .lunch)) },
                    onLeftoversForTomorrowDinner: { onAddLeftovers(position, tomorrowPosition(mealType: .dinner)) }
                )
            }
        } header: {
            HStack {
                Text(headerText)
                    .id(Self.headerID(dayIndex: dayIndex))
                if !isReadOnly {
                    Spacer()
                    Button {
                        onRandomizeDay(dayIndex)
                    } label: {
                        Image(systemName: "dice")
                    }
                    .accessibilityLabel("Randomise")
                }
            }
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
        guard !isReadOnly, let slot = slot(mealType), slot.isLeftovers, let sourceID = slot.leftoverOfSlotID else { return nil }
        return context.sourceLabels[sourceID]
    }

    /// "Mark as Leftovers" and "Leftovers for Tomorrow's …" are only offered
    /// for a meal that's still `goodAsLeftovers` (§7.7 v1.3, §10.1) —
    /// `LeftoverRules` itself doesn't know about the flag, so it's checked here.
    private func menuFlags(_ mealType: MealType, position: PlanPosition) -> PlanSlotMenuFlags {
        guard !isReadOnly, let slot = slot(mealType), slot.meal?.goodAsLeftovers != false else { return .none }
        return LeftoverRules.slotMenuFlags(
            mealID: slot.meal?.id, isLeftovers: slot.isLeftovers, position: position,
            context: context, calendar: WeekMath.appCalendar
        )
    }
}
