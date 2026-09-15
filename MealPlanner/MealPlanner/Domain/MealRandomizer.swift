import Foundation

/// `MealRandomizer` itself (the pick algorithm, §7.6) arrives in M8. `RandomizeMode`
/// is needed now because `WeekPlanService.copyWeek` (M6) shares it for Fill
/// Empty / Replace target semantics.
enum RandomizeMode: String, CaseIterable, Sendable {
    case fillEmpty, replaceAll
}
