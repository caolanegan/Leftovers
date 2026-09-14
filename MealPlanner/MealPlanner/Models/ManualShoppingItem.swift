import Foundation
import SwiftData

@Model
final class ManualShoppingItem {               // added by hand to a week's list
    var id: UUID = UUID()
    var quantity: Double? = nil
    var unitRaw: String = IngredientUnit.item.rawValue
    var createdAt: Date = Date.now
    var weekPlan: WeekPlan?
    var ingredient: Ingredient?

    init(ingredient: Ingredient, quantity: Double?, unit: IngredientUnit) {
        self.ingredient = ingredient
        self.quantity = quantity
        self.unitRaw = unit.rawValue
    }

    var unit: IngredientUnit {
        get { IngredientUnit(rawValue: unitRaw) ?? .item }
        set { unitRaw = newValue.rawValue }
    }
}
