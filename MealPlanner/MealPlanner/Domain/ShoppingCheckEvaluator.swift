import Foundation

enum CheckStatus: Equatable, Codable, Sendable {
    case unchecked
    case checked
    case needsMore([IngredientUnit: Double])
}

enum ShoppingCheckEvaluator {
    /// §7.5: compares what the list needs now with what was remembered at the
    /// last tick. Needing the same or less stays checked; needing more surfaces
    /// the extra amount per unit.
    static func status(for item: ShoppingListItem, isChecked: Bool?, checkedAmounts: [IngredientUnit: Double]) -> CheckStatus {
        guard isChecked == true else { return .unchecked }

        var extras: [IngredientUnit: Double] = [:]
        for (unit, amount) in item.amounts {
            let extra = amount - (checkedAmounts[unit] ?? 0)
            if extra > 0.0001 { extras[unit] = extra }
        }
        return extras.isEmpty ? .checked : .needsMore(extras)
    }
}
