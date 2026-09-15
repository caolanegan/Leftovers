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
