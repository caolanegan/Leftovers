import Foundation

struct ExportOptions: Equatable, Sendable {
    var includeChecked = false
    var includeMealPlan = true
}

struct ExportMeal: Equatable, Sendable {
    let name: String
    let isLeftovers: Bool
}

struct ExportDay: Equatable, Sendable {
    let dayIndex: Int
    let meals: [ExportMeal]                           // B/L/D order
}

/// §7.9: renders a shopping list (and optionally the week's meal plan) as
/// WhatsApp-friendly plain text.
enum ShoppingListExporter {
    static func text(
        weekCommencing: String, sections: [ShoppingListSection], statuses: [String: CheckStatus],
        mealPlan: [ExportDay], options: ExportOptions
    ) -> String {
        var blocks = ["*Shopping list · \(weekCommencing)*"]

        for section in sections {
            let lines = section.items.compactMap { itemLine(for: $0, statuses: statuses, includeChecked: options.includeChecked) }
            guard !lines.isEmpty else { continue }
            blocks.append((["*\(section.category.displayName)*"] + lines).joined(separator: "\n"))
        }

        if options.includeMealPlan {
            let dayLines = mealPlan.compactMap(dayLine)
            if !dayLines.isEmpty {
                blocks.append((["*Meals*"] + dayLines).joined(separator: "\n"))
            }
        }

        return blocks.joined(separator: "\n\n")
    }

    static func hasExportableItems(sections: [ShoppingListSection], statuses: [String: CheckStatus], options: ExportOptions) -> Bool {
        sections.flatMap(\.items).contains { itemLine(for: $0, statuses: statuses, includeChecked: options.includeChecked) != nil }
    }

    private static func itemLine(for item: ShoppingListItem, statuses: [String: CheckStatus], includeChecked: Bool) -> String? {
        switch statuses[item.key] ?? .unchecked {
        case .unchecked:
            return "• \(item.displayName)\(amountSuffix(item.amounts))"
        case .needsMore(let extra):
            return "• \(item.displayName) – \(QuantityFormatter.format(amounts: extra)) more"
        case .checked:
            guard includeChecked else { return nil }
            return "✓ \(item.displayName)\(amountSuffix(item.amounts))"
        }
    }

    private static func amountSuffix(_ amounts: [IngredientUnit: Double]) -> String {
        let text = QuantityFormatter.format(amounts: amounts)
        return text.isEmpty ? "" : " – \(text)"
    }

    private static func dayLine(_ day: ExportDay) -> String? {
        guard !day.meals.isEmpty else { return nil }
        let meals = day.meals.map { $0.isLeftovers ? "\($0.name) (leftovers)" : $0.name }.joined(separator: ", ")
        return "\(WeekMath.shortDayName(day.dayIndex)): \(meals)"
    }
}
