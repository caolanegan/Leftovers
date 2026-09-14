import Foundation
import SwiftData

@Model
final class WeekPlan {
    var id: UUID = UUID()
    var weekID: String = ""                    // "2026-W38"; unique (service-enforced)
    var createdAt: Date = Date.now
    var isArchived: Bool = false               // §6.7
    var archivedAt: Date? = nil
    var archivedShoppingJSON: String? = nil    // ArchivedShoppingList (§7.8), set on archive
    var lastSharedAt: Date? = nil
    var lastSharedSignature: String? = nil

    @Relationship(deleteRule: .cascade, inverse: \MealSlot.weekPlan)
    var slots: [MealSlot]? = []
    @Relationship(deleteRule: .cascade, inverse: \ManualShoppingItem.weekPlan)
    var manualItems: [ManualShoppingItem]? = []
    @Relationship(deleteRule: .cascade, inverse: \ShoppingItemState.weekPlan)
    var itemStates: [ShoppingItemState]? = []

    init(weekID: String) {
        self.weekID = weekID
    }
}
