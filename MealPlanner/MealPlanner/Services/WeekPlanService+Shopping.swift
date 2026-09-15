import Foundation
import SwiftData

extension WeekPlanService {
    /// §7.4's input order: every cooked (non-leftover) filled slot's recipe
    /// lines, day ascending then B → L → D then `sortIndex`, followed by the
    /// week's hand-added items in `createdAt` order. Recipe lines with no
    /// ingredient are skipped. Reads straight off live models, so it's also
    /// what `ArchiveService` calls at archive time, before the week freezes.
    func shoppingLines(for plan: WeekPlan) -> [ShoppingLine] {
        var lines: [ShoppingLine] = []

        let slots = (plan.slots ?? []).sorted { lhs, rhs in
            lhs.dayIndex != rhs.dayIndex ? lhs.dayIndex < rhs.dayIndex : lhs.mealType < rhs.mealType
        }
        for slot in slots where !slot.isLeftovers {
            guard let meal = slot.meal else { continue }
            for line in meal.sortedIngredients {
                guard let ingredient = line.ingredient else { continue }
                lines.append(ShoppingLine(
                    ingredientKey: ingredient.id.uuidString, name: ingredient.name, category: ingredient.category,
                    quantity: line.quantity, unit: line.unit, source: .meal(meal.name)
                ))
            }
        }

        let manualItems = (plan.manualItems ?? []).sorted { $0.createdAt < $1.createdAt }
        for item in manualItems {
            guard let ingredient = item.ingredient else { continue }
            lines.append(ShoppingLine(
                ingredientKey: ingredient.id.uuidString, name: ingredient.name, category: ingredient.category,
                quantity: item.quantity, unit: item.unit, source: .manual
            ))
        }

        return lines
    }

    /// One `CheckStatus` per item, defaulting to `.unchecked` when no
    /// `ShoppingItemState` has been saved for it yet.
    func statuses(for plan: WeekPlan, sections: [ShoppingListSection]) -> [String: CheckStatus] {
        let states = Dictionary((plan.itemStates ?? []).map { ($0.itemKey, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [String: CheckStatus] = [:]
        for item in sections.flatMap(\.items) {
            let state = states[item.key]
            result[item.key] = ShoppingCheckEvaluator.status(for: item, isChecked: state?.isChecked, checkedAmounts: state?.checkedAmounts ?? [:])
        }
        return result
    }

    /// Ticking stores `item.amounts` as the remembered "needed at that moment"
    /// snapshot (§7.5); unticking just flips the flag.
    func setChecked(_ checked: Bool, item: ShoppingListItem, weekID: String) throws {
        try ArchiveService(context: context, now: now, calendar: calendar).archiveEndedWeeks()
        guard !WeekMath.isEnded(weekID, now: now, calendar: calendar) else { throw AppError.weekIsArchived }

        let plan = try fetchOrCreatePlan(for: weekID)
        let state = itemState(for: item.key, in: plan) ?? {
            let newState = ShoppingItemState(itemKey: item.key)
            newState.weekPlan = plan
            context.insert(newState)
            return newState
        }()
        state.isChecked = checked
        if checked { state.checkedAmounts = item.amounts }
        try context.save()
    }

    func uncheckAll(weekID: String) throws {
        try ArchiveService(context: context, now: now, calendar: calendar).archiveEndedWeeks()
        guard !WeekMath.isEnded(weekID, now: now, calendar: calendar) else { throw AppError.weekIsArchived }
        guard let plan = try plan(for: weekID) else { return }

        for state in plan.itemStates ?? [] { state.isChecked = false }
        try context.save()
    }

    /// At most one hand-added item per (week, ingredient) — §3. Editing an
    /// existing one replaces its amount/unit rather than adding a second row.
    func upsertManualItem(ingredient: Ingredient, quantity: Double?, unit: IngredientUnit, weekID: String) throws {
        try ArchiveService(context: context, now: now, calendar: calendar).archiveEndedWeeks()
        guard !WeekMath.isEnded(weekID, now: now, calendar: calendar) else { throw AppError.weekIsArchived }

        let plan = try fetchOrCreatePlan(for: weekID)
        if let existing = try manualItem(ingredientID: ingredient.id, weekID: weekID) {
            existing.quantity = quantity
            existing.unit = unit
        } else {
            let item = ManualShoppingItem(ingredient: ingredient, quantity: quantity, unit: unit)
            item.weekPlan = plan
            context.insert(item)
        }
        try context.save()
    }

    func removeManualItem(ingredientID: UUID, weekID: String) throws {
        try ArchiveService(context: context, now: now, calendar: calendar).archiveEndedWeeks()
        guard !WeekMath.isEnded(weekID, now: now, calendar: calendar) else { throw AppError.weekIsArchived }
        guard let item = try manualItem(ingredientID: ingredientID, weekID: weekID) else { return }

        context.delete(item)
        try context.save()
    }

    func manualItem(ingredientID: UUID, weekID: String) throws -> ManualShoppingItem? {
        guard let plan = try plan(for: weekID) else { return nil }
        return (plan.manualItems ?? []).first { $0.ingredient?.id == ingredientID }
    }

    /// No-op (rather than throwing) on an archived week: sharing an ended
    /// week's frozen list is still allowed (§10.10), it just never updates
    /// `lastSharedSignature`.
    func markShared(weekID: String, signature: String) throws {
        try ArchiveService(context: context, now: now, calendar: calendar).archiveEndedWeeks()
        guard !WeekMath.isEnded(weekID, now: now, calendar: calendar) else { return }

        let plan = try fetchOrCreatePlan(for: weekID)
        plan.lastSharedAt = now
        plan.lastSharedSignature = signature
        try context.save()
    }

    private func itemState(for key: String, in plan: WeekPlan) -> ShoppingItemState? {
        (plan.itemStates ?? []).first { $0.itemKey == key }
    }
}
