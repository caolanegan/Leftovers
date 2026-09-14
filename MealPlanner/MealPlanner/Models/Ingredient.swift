import Foundation
import SwiftData

@Model
final class Ingredient {
    var id: UUID = UUID()
    var name: String = ""                                   // unique by NameNormalizer.key (service-enforced)
    var defaultUnitRaw: String = IngredientUnit.item.rawValue
    var categoryRaw: String = ShoppingCategory.other.rawValue
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \RecipeIngredient.ingredient)
    var recipeUses: [RecipeIngredient]? = []
    @Relationship(deleteRule: .nullify, inverse: \ManualShoppingItem.ingredient)
    var manualUses: [ManualShoppingItem]? = []

    init(name: String, defaultUnit: IngredientUnit, category: ShoppingCategory) {
        self.name = name
        self.defaultUnitRaw = defaultUnit.rawValue
        self.categoryRaw = category.rawValue
    }

    var defaultUnit: IngredientUnit {
        get { IngredientUnit(rawValue: defaultUnitRaw) ?? .item }
        set { defaultUnitRaw = newValue.rawValue }
    }

    var category: ShoppingCategory {
        get { ShoppingCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var usedInMeals: [Meal] {
        var seen = Set<UUID>()
        var result: [Meal] = []
        for use in recipeUses ?? [] {
            guard let meal = use.meal, !seen.contains(meal.id) else { continue }
            seen.insert(meal.id)
            result.append(meal)
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
