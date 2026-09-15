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
}
