import Foundation
import SwiftData

@Model
final class RecipeIngredient {                 // one line in a recipe
    var id: UUID = UUID()
    var quantity: Double? = nil                // nil = unquantified ("to taste")
    var unitRaw: String = IngredientUnit.item.rawValue
    var note: String = ""                      // e.g. "finely chopped"
    var sortIndex: Int = 0
    var meal: Meal?
    var ingredient: Ingredient?

    init(ingredient: Ingredient, quantity: Double?, unit: IngredientUnit, note: String, sortIndex: Int) {
        self.ingredient = ingredient
        self.quantity = quantity
        self.unitRaw = unit.rawValue
        self.note = note
        self.sortIndex = sortIndex
    }

    var unit: IngredientUnit {
        get { IngredientUnit(rawValue: unitRaw) ?? .item }
        set { unitRaw = newValue.rawValue }
    }
}
