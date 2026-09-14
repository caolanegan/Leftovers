import Foundation
import SwiftData

@Model
final class ShoppingItemState {
    var id: UUID = UUID()
    var itemKey: String = ""                   // Ingredient.id.uuidString
    var isChecked: Bool = false
    var checkedAmountsJSON: String = "{}"      // [IngredientUnit: Double] captured when ticked (§7.5)
    var weekPlan: WeekPlan?

    init(itemKey: String) {
        self.itemKey = itemKey
    }

    var checkedAmounts: [IngredientUnit: Double] {
        get {
            guard let data = checkedAmountsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([IngredientUnit: Double].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(newValue),
                  let json = String(data: data, encoding: .utf8)
            else {
                checkedAmountsJSON = "{}"
                return
            }
            checkedAmountsJSON = json
        }
    }
}
