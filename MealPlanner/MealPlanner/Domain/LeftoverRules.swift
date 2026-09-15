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

/// `sourceCandidates` (the "Leftovers or cook again?" matching algorithm, §7.7) arrives in M7.
enum LeftoverRules {
    /// Human label for a source slot, e.g. "Mon dinner".
    static func label(for position: PlanPosition) -> String {
        "\(WeekMath.shortDayName(position.dayIndex)) \(position.mealType.displayName.lowercased())"
    }
}
