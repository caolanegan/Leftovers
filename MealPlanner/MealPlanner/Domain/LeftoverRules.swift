import Foundation

/// A day/meal-type slot in a specific week, independent of any live `MealSlot` row.
struct PlanPosition: Hashable, Sendable {
    let weekID: String
    let dayIndex: Int
    let mealType: MealType
}

/// One filled slot (live or archived), used for cross-week reads like "had last week".
struct PlanOccurrence: Hashable, Sendable {
    let slotID: UUID
    let position: PlanPosition
    let mealID: UUID
    let isLeftovers: Bool
}

/// Precomputed once per Plan-screen render (`WeekPlanContentView.planContext`)
/// so `DaySection`/`MealSlotRow` can derive their per-row context-menu flags
/// with no further `WeekPlanService` fetches.
struct PlanWeekContext: Sendable {
    /// This week's occurrences plus the previous week's (as `WeekPlanService.occurrences(around:)`).
    var occurrences: [PlanOccurrence] = []
    /// Every position with a live filled slot, across this week and next week's Monday
    /// (so a Sunday row's "Leftovers for Tomorrow" can see across the week boundary).
    var filledPositions: Set<PlanPosition> = []
    /// A leftover slot's source slot id → its human label ("Mon dinner"), derived from `occurrences`.
    var sourceLabels: [UUID: String] = [:]

    static let empty = PlanWeekContext()
}

/// Whether a filled, cooked slot should offer "Mark as Leftovers" and
/// "Leftovers for Tomorrow's Lunch/Dinner" in its context menu (§10.1).
struct PlanSlotMenuFlags: Equatable {
    let canMarkAsLeftovers: Bool
    let leftoversForTomorrowLunch: Bool
    let leftoversForTomorrowDinner: Bool

    static let none = PlanSlotMenuFlags(canMarkAsLeftovers: false, leftoversForTomorrowLunch: false, leftoversForTomorrowDinner: false)
}

enum LeftoverRules {
    static let maxDaysLater = 3

    /// Cooked occurrences of `mealID` that `target` could be leftovers of, nearest first.
    static func sourceCandidates(
        mealID: UUID, target: PlanPosition, occurrences: [PlanOccurrence], calendar: Calendar
    ) -> [PlanOccurrence] {
        occurrences
            .filter { $0.mealID == mealID && !$0.isLeftovers }
            .compactMap { occurrence -> (PlanOccurrence, Int)? in
                let distance = WeekMath.dayDistance(
                    from: (occurrence.position.weekID, occurrence.position.dayIndex),
                    to: (target.weekID, target.dayIndex),
                    calendar: calendar
                )
                let isValid = (1...maxDaysLater).contains(distance)
                    || (distance == 0 && occurrence.position.mealType < target.mealType)
                guard isValid else { return nil }
                return (occurrence, distance)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.position.mealType > rhs.0.position.mealType   // later meal type first
            }
            .map(\.0)
    }

    /// Derives a filled row's leftovers context-menu flags (§10.1) purely from
    /// a precomputed `PlanWeekContext` — no fetches. `mealID`/`isLeftovers`
    /// nil/true means an empty or already-leftovers slot, which offers none of these.
    static func slotMenuFlags(
        mealID: UUID?, isLeftovers: Bool, position: PlanPosition, context: PlanWeekContext, calendar: Calendar
    ) -> PlanSlotMenuFlags {
        guard let mealID, !isLeftovers else { return .none }

        let canMark = !sourceCandidates(mealID: mealID, target: position, occurrences: context.occurrences, calendar: calendar).isEmpty
        let (nextWeekID, nextDayIndex) = WeekMath.nextDay(weekID: position.weekID, dayIndex: position.dayIndex, calendar: calendar)
        let tomorrowLunch = PlanPosition(weekID: nextWeekID, dayIndex: nextDayIndex, mealType: .lunch)
        let tomorrowDinner = PlanPosition(weekID: nextWeekID, dayIndex: nextDayIndex, mealType: .dinner)
        return PlanSlotMenuFlags(
            canMarkAsLeftovers: canMark,
            leftoversForTomorrowLunch: !context.filledPositions.contains(tomorrowLunch),
            leftoversForTomorrowDinner: !context.filledPositions.contains(tomorrowDinner)
        )
    }

    /// Human label for a source slot, e.g. "Mon dinner".
    static func label(for position: PlanPosition) -> String {
        "\(WeekMath.shortDayName(position.dayIndex)) \(position.mealType.displayName.lowercased())"
    }

    /// Title for the dependent-leftovers dialog (§10.3 B), e.g. "Monday dinner has leftovers planned".
    static func dependentPromptTitle(for position: PlanPosition) -> String {
        "\(fullLabel(for: position)) has leftovers planned"
    }

    /// Message for the dependent-leftovers dialog (§10.3 B), e.g. "Tuesday lunch is leftovers from this meal."
    /// The spec's example only covers one dependent; multiple are joined ("X and Y are…").
    static func dependentPromptMessage(for dependents: [PlanPosition]) -> String {
        let labels = dependents.map(fullLabel(for:))
        let verb = labels.count == 1 ? "is" : "are"
        return "\(joined(labels)) \(verb) leftovers from this meal."
    }

    private static func fullLabel(for position: PlanPosition) -> String {
        "\(WeekMath.fullDayName(position.dayIndex)) \(position.mealType.displayName.lowercased())"
    }

    private static func joined(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        default: "\(items.dropLast().joined(separator: ", ")) and \(items.last!)"
        }
    }
}
