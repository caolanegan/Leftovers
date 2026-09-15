import Foundation
import SwiftData

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
            archiveShoppingList(plan)
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

    /// `nil` for a week archived before M9 added this step — the caller
    /// shows "No shopping list was saved for this week" rather than
    /// rebuilding one from (now current, not historical) live data.
    func archivedShoppingList(_ plan: WeekPlan) -> ArchivedShoppingList? {
        guard let json = plan.archivedShoppingJSON else { return nil }
        return try? ArchiveCoding.decode(ArchivedShoppingList.self, from: json)
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
        try? WeekPlanService(context: context, now: now, calendar: calendar).sourceLabel(for: slot)
    }

    /// Built from live data before the week freezes, same as `archiveSlot`
    /// above — meals/ingredients are still intact at this point in the loop.
    private func archiveShoppingList(_ plan: WeekPlan) {
        let service = WeekPlanService(context: context, now: now, calendar: calendar)
        let lines = service.shoppingLines(for: plan)
        let sections = ShoppingListBuilder.build(from: lines)
        let statuses = service.statuses(for: plan, sections: sections)
        plan.archivedShoppingJSON = try? ArchiveCoding.encode(ArchivedShoppingList(sections: sections, statuses: statuses))
    }
}
