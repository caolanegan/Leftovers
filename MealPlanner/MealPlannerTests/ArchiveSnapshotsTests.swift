import Foundation
import Testing
@testable import MealPlanner

@MainActor
struct ArchiveSnapshotsTests {
    @Test func archivedSlotRoundTripsThroughJSON() throws {
        let slot = ArchivedSlot(
            slotID: UUID(),
            mealID: UUID(),
            mealName: "Spaghetti bolognese",
            leftoverOfSlotID: UUID(),
            leftoverSourceLabel: "Mon dinner",
            ingredients: [
                ArchivedIngredientLine(name: "Beef mince", amountText: "500 g", note: ""),
                ArchivedIngredientLine(name: "Salt", amountText: "", note: "to taste"),
            ]
        )

        let json = try ArchiveCoding.encode(slot)
        let decoded = try ArchiveCoding.decode(ArchivedSlot.self, from: json)

        #expect(decoded == slot)
    }

    @Test func archivedSlotWithNoMealRoundTrips() throws {
        let slot = ArchivedSlot(
            slotID: UUID(),
            mealID: nil,
            mealName: "Deleted meal",
            leftoverOfSlotID: nil,
            leftoverSourceLabel: nil,
            ingredients: []
        )

        let json = try ArchiveCoding.encode(slot)
        let decoded = try ArchiveCoding.decode(ArchivedSlot.self, from: json)

        #expect(decoded == slot)
    }

    @Test func archivedShoppingListRoundTripsEveryCheckStatusCase() throws {
        let item = ShoppingListItem(key: "k", displayName: "Chicken breast", category: .meatFish, amounts: [.g: 200], usedIn: ["Fajitas"], hasManualEntry: false)
        let section = ShoppingListSection(category: .meatFish, items: [item])
        let list = ArchivedShoppingList(
            sections: [section],
            statuses: [
                "unchecked-key": .unchecked,
                "checked-key": .checked,
                "needsMore-key": .needsMore([.g: 150]),
            ]
        )

        let json = try ArchiveCoding.encode(list)
        let decoded = try ArchiveCoding.decode(ArchivedShoppingList.self, from: json)

        #expect(decoded == list)
    }
}
