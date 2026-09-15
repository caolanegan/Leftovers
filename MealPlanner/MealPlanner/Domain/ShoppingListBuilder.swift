import Foundation

enum ShoppingLineSource: Hashable, Codable, Sendable {
    case meal(String)
    case manual
}

struct ShoppingLine: Equatable, Sendable {
    let ingredientKey: String        // Ingredient.id.uuidString
    let name: String                 // Ingredient.name
    let category: ShoppingCategory   // Ingredient.category
    let quantity: Double?
    let unit: IngredientUnit
    let source: ShoppingLineSource
}

struct ShoppingListItem: Identifiable, Equatable, Codable, Sendable {
    var id: String { key }
    let key: String                          // ingredientKey
    let displayName: String
    let category: ShoppingCategory
    let amounts: [IngredientUnit: Double]    // base units only; empty = unquantified
    let usedIn: [String]                     // unique meal names, first-seen order
    let hasManualEntry: Bool
}

struct ShoppingListSection: Identifiable, Equatable, Codable, Sendable {
    var id: ShoppingCategory { category }
    let category: ShoppingCategory
    let items: [ShoppingListItem]
}

enum ShoppingListBuilder {
    /// §7.4: groups by `ingredientKey` (never by name), sums quantities in base
    /// units, and sections/sorts the result. Lines with different keys are
    /// never merged, even if their names happen to match.
    static func build(from lines: [ShoppingLine]) -> [ShoppingListSection] {
        var order: [String] = []
        var grouped: [String: [ShoppingLine]] = [:]
        for line in lines {
            if grouped[line.ingredientKey] == nil { order.append(line.ingredientKey) }
            grouped[line.ingredientKey, default: []].append(line)
        }

        var itemsByCategory: [ShoppingCategory: [ShoppingListItem]] = [:]
        for key in order {
            guard let groupLines = grouped[key], let first = groupLines.first else { continue }

            var amounts: [IngredientUnit: Double] = [:]
            var usedIn: [String] = []
            var hasManualEntry = false
            for line in groupLines {
                if let quantity = line.quantity {
                    amounts[line.unit.baseUnit, default: 0] += quantity * line.unit.toBaseMultiplier
                }
                switch line.source {
                case .meal(let mealName):
                    if !usedIn.contains(mealName) { usedIn.append(mealName) }
                case .manual:
                    hasManualEntry = true
                }
            }

            let item = ShoppingListItem(
                key: key, displayName: first.name, category: first.category,
                amounts: amounts, usedIn: usedIn, hasManualEntry: hasManualEntry
            )
            itemsByCategory[first.category, default: []].append(item)
        }

        return ShoppingCategory.allCases.compactMap { category in
            guard let items = itemsByCategory[category], !items.isEmpty else { return nil }
            let sorted = items.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            return ShoppingListSection(category: category, items: sorted)
        }
    }

    /// A deterministic string of every item's key, amounts and `hasManualEntry`,
    /// in list order — used to detect "your list has changed since you shared
    /// it" (§10.10, wired up in M10).
    static func signature(of sections: [ShoppingListSection]) -> String {
        sections.flatMap(\.items).map { item in
            let amountsPart = item.amounts
                .map { unit, amount in "\(unit.rawValue):\(String(format: "%.3f", amount))" }
                .sorted()
                .joined(separator: ",")
            return "\(item.key)|\(amountsPart)|\(item.hasManualEntry)"
        }.joined(separator: ";")
    }
}
