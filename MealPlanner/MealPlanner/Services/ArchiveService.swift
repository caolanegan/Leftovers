import Foundation
import SwiftData

/// `archivedShoppingList(_:)` and step 3 of `archiveEndedWeeks` (building the
/// shopping snapshot) arrive in M9 with `ShoppingListBuilder`/
/// `ShoppingCheckEvaluator` (§8.1 is read "slots only" for M6).
@MainActor
struct ArchiveService {
    let context: ModelContext
    var now: Date = .now
    var calendar: Calendar = WeekMath.appCalendar

    @discardableResult
    func archiveEndedWeeks() throws -> Int {
        let plans = try context.fetch(FetchDescriptor<WeekPlan>()).filter { !$0.isArchived }
        let ended = plans.filter { WeekMath.isEnded($0.weekID, now: now, calendar: calendar) }
        guard !ended.isEmpty else { return 0 }

        for plan in ended {
            for slot in plan.slots ?? [] {
                archiveSlot(slot)
            }
            plan.isArchived = true
            plan.archivedAt = now
        }

        try context.save()
        return ended.count
    }

    func archivedSlot(_ slot: MealSlot) -> ArchivedSlot? {
        guard let json = slot.archivedSnapshotJSON else { return nil }
        return try? ArchiveCoding.decode(ArchivedSlot.self, from: json)
    }

    // MARK: - Private

    private func archiveSlot(_ slot: MealSlot) {
        guard let meal = slot.meal else {
            context.delete(slot)
            return
        }

        let snapshot: ArchivedSlot
        if slot.isLeftovers {
            snapshot = ArchivedSlot(
                slotID: slot.id,
                mealID: meal.id,
                mealName: meal.name,
                leftoverOfSlotID: slot.leftoverOfSlotID,
                leftoverSourceLabel: sourceLabel(for: slot),
                ingredients: []
            )
        } else {
            let lines = meal.sortedIngredients.map { line in
                ArchivedIngredientLine(
                    name: line.ingredient?.name ?? "",
                    amountText: line.quantity.map { QuantityFormatter.format($0, unit: line.unit) } ?? "",
                    note: line.note
                )
            }
            snapshot = ArchivedSlot(
                slotID: slot.id,
                mealID: meal.id,
                mealName: meal.name,
                leftoverOfSlotID: nil,
                leftoverSourceLabel: nil,
                ingredients: lines
            )
        }

        slot.archivedSnapshotJSON = try? ArchiveCoding.encode(snapshot)
    }

    private func sourceLabel(for slot: MealSlot) -> String? {
        guard let sourceID = slot.leftoverOfSlotID else { return nil }
        var descriptor = FetchDescriptor<MealSlot>(predicate: #Predicate<MealSlot> { $0.id == sourceID })
        descriptor.fetchLimit = 1
        guard let source = try? context.fetch(descriptor).first else { return nil }
        let position = PlanPosition(weekID: source.weekPlan?.weekID ?? "", dayIndex: source.dayIndex, mealType: source.mealType)
        return LeftoverRules.label(for: position)
    }
}
