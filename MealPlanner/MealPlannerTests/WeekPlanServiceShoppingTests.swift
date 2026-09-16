import Foundation
import Testing
import SwiftData
@testable import MealPlanner

@MainActor
struct WeekPlanServiceShoppingTests {
    let container: ModelContainer
    let context: ModelContext
    let mealStore: MealStore
    let ingredientStore: IngredientStore
    let service: WeekPlanService
    let calendar = WeekMath.appCalendar
    let now: Date

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        context = container.mainContext
        mealStore = MealStore(context: context)
        ingredientStore = IngredientStore(context: context)

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        now = try #require(formatter.date(from: "2026-09-14 09:00"))
        service = WeekPlanService(context: context, now: now, calendar: calendar)
    }

    private func makeMeal(_ name: String, ingredient: Ingredient, quantity: Double?, unit: IngredientUnit) throws -> Meal {
        var draft = MealDraft()
        draft.name = name
        draft.mealTypes = [.dinner]
        draft.lines = [RecipeLineDraft(id: UUID(), ingredientID: ingredient.id, ingredientName: ingredient.name, quantity: quantity, unit: unit, note: "")]
        return try mealStore.create(from: draft)
    }

    // MARK: - shoppingLines

    @Test func shoppingLinesSkipLeftoverSlotsButIncludeCookedOnes() throws {
        let chicken = try ingredientStore.create(name: "Chicken", defaultUnit: .g, category: .meatFish)
        let meal = try makeMeal("Fajitas", ingredient: chicken, quantity: 200, unit: .g)
        let position = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: position)
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch), leftoversOf: nil)
        // Turn Tuesday lunch into leftovers of Monday dinner directly (bypassing the prompt flow).
        let plan = try #require(try service.plan(for: "2026-W38"))
        let mondayDinner = try #require((plan.slots ?? []).first { $0.dayIndex == 0 && $0.mealType == .dinner })
        let tuesdayLunch = try #require((plan.slots ?? []).first { $0.dayIndex == 1 && $0.mealType == .lunch })
        tuesdayLunch.leftoverOfSlotID = mondayDinner.id
        try context.save()

        let lines = service.shoppingLines(for: plan)

        #expect(lines.count == 1)
        #expect(lines.first?.ingredientKey == chicken.id.uuidString)
    }

    @Test func shoppingLinesPutManualItemsAfterMealLines() throws {
        let onion = try ingredientStore.create(name: "Onion", defaultUnit: .item, category: .produce)
        let meal = try makeMeal("Soup", ingredient: onion, quantity: 1, unit: .item)
        let position = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: position)
        let toiletRoll = try ingredientStore.create(name: "Toilet roll", defaultUnit: .pack, category: .household)
        try service.upsertManualItem(ingredient: toiletRoll, quantity: 1, unit: .pack, weekID: "2026-W38")

        let plan = try #require(try service.plan(for: "2026-W38"))
        let lines = service.shoppingLines(for: plan)

        #expect(lines.map(\.ingredientKey) == [onion.id.uuidString, toiletRoll.id.uuidString])
        #expect(lines.last?.source == .manual)
    }

    @Test func shoppingLinesSkipRecipeLinesWithNoIngredient() throws {
        let onion = try ingredientStore.create(name: "Onion", defaultUnit: .item, category: .produce)
        let meal = try makeMeal("Soup", ingredient: onion, quantity: 1, unit: .item)
        // Directly null out the line's ingredient (bypassing the store, which
        // refuses to delete an ingredient still in use) to exercise the guard.
        meal.sortedIngredients.first?.ingredient = nil
        try context.save()
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner))

        let plan = try #require(try service.plan(for: "2026-W38"))
        #expect(service.shoppingLines(for: plan).isEmpty)
    }

    // MARK: - statuses / setChecked

    @Test func statusDefaultsToUncheckedWithNoSavedState() throws {
        let onion = try ingredientStore.create(name: "Onion", defaultUnit: .item, category: .produce)
        let meal = try makeMeal("Soup", ingredient: onion, quantity: 1, unit: .item)
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner))
        let plan = try #require(try service.plan(for: "2026-W38"))
        let sections = ShoppingListBuilder.build(from: service.shoppingLines(for: plan))

        let statuses = service.statuses(for: plan, sections: sections)

        #expect(statuses[onion.id.uuidString] == .unchecked)
    }

    @Test func settingCheckedStoresTheAmountsAndLaterNeedsMoreIfDemandGrows() throws {
        let chicken = try ingredientStore.create(name: "Chicken", defaultUnit: .g, category: .meatFish)
        let meal = try makeMeal("Fajitas", ingredient: chicken, quantity: 200, unit: .g)
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner))
        var plan = try #require(try service.plan(for: "2026-W38"))
        var sections = ShoppingListBuilder.build(from: service.shoppingLines(for: plan))
        let item = try #require(sections.first?.items.first)

        try service.setChecked(true, item: item, weekID: "2026-W38")
        #expect(service.statuses(for: plan, sections: sections)[item.key] == .checked)

        let wraps = try makeMeal("Wrap", ingredient: chicken, quantity: 150, unit: .g)
        try service.assign(wraps, at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch))
        plan = try #require(try service.plan(for: "2026-W38"))
        sections = ShoppingListBuilder.build(from: service.shoppingLines(for: plan))
        let grownItem = try #require(sections.first?.items.first)

        #expect(service.statuses(for: plan, sections: sections)[item.key] == .needsMore([.g: 150]))
        #expect(grownItem.amounts == [.g: 350])
    }

    @Test func uncheckAllUnticksEveryTickedItem() throws {
        let onion = try ingredientStore.create(name: "Onion", defaultUnit: .item, category: .produce)
        let meal = try makeMeal("Soup", ingredient: onion, quantity: 1, unit: .item)
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner))
        let plan = try #require(try service.plan(for: "2026-W38"))
        let sections = ShoppingListBuilder.build(from: service.shoppingLines(for: plan))
        let item = try #require(sections.first?.items.first)
        try service.setChecked(true, item: item, weekID: "2026-W38")

        try service.uncheckAll(weekID: "2026-W38")

        #expect(service.statuses(for: plan, sections: sections)[item.key] == .unchecked)
    }

    @Test func uncheckAllResetsANeedsMoreItemToUnchecked() throws {
        let chicken = try ingredientStore.create(name: "Chicken", defaultUnit: .g, category: .meatFish)
        let meal = try makeMeal("Fajitas", ingredient: chicken, quantity: 200, unit: .g)
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner))
        var plan = try #require(try service.plan(for: "2026-W38"))
        var sections = ShoppingListBuilder.build(from: service.shoppingLines(for: plan))
        let item = try #require(sections.first?.items.first)
        try service.setChecked(true, item: item, weekID: "2026-W38")

        let wraps = try makeMeal("Wrap", ingredient: chicken, quantity: 150, unit: .g)
        try service.assign(wraps, at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch))
        plan = try #require(try service.plan(for: "2026-W38"))
        sections = ShoppingListBuilder.build(from: service.shoppingLines(for: plan))
        #expect(service.statuses(for: plan, sections: sections)[item.key] == .needsMore([.g: 150]))

        try service.uncheckAll(weekID: "2026-W38")

        #expect(service.statuses(for: plan, sections: sections)[item.key] == .unchecked)
    }

    @Test func settingCheckedOnAnEndedWeekThrows() throws {
        let onion = try ingredientStore.create(name: "Onion", defaultUnit: .item, category: .produce)
        let item = ShoppingListItem(key: onion.id.uuidString, displayName: onion.name, category: .produce, amounts: [.item: 1], usedIn: [], hasManualEntry: false)

        #expect(throws: AppError.weekIsArchived) {
            try service.setChecked(true, item: item, weekID: "2026-W37")
        }
    }

    // MARK: - Manual items

    @Test func upsertManualItemAddsThenEditsInPlace() throws {
        let toiletRoll = try ingredientStore.create(name: "Toilet roll", defaultUnit: .pack, category: .household)

        try service.upsertManualItem(ingredient: toiletRoll, quantity: 1, unit: .pack, weekID: "2026-W38")
        try service.upsertManualItem(ingredient: toiletRoll, quantity: 2, unit: .pack, weekID: "2026-W38")

        let plan = try #require(try service.plan(for: "2026-W38"))
        #expect((plan.manualItems ?? []).count == 1)
        #expect((plan.manualItems ?? []).first?.quantity == 2)
    }

    @Test func removeManualItemDeletesIt() throws {
        let toiletRoll = try ingredientStore.create(name: "Toilet roll", defaultUnit: .pack, category: .household)
        try service.upsertManualItem(ingredient: toiletRoll, quantity: 1, unit: .pack, weekID: "2026-W38")

        try service.removeManualItem(ingredientID: toiletRoll.id, weekID: "2026-W38")

        #expect(try service.manualItem(ingredientID: toiletRoll.id, weekID: "2026-W38") == nil)
    }

    @Test func manualItemIsNilWhenNoneExists() throws {
        let toiletRoll = try ingredientStore.create(name: "Toilet roll", defaultUnit: .pack, category: .household)
        #expect(try service.manualItem(ingredientID: toiletRoll.id, weekID: "2026-W38") == nil)
    }

    // MARK: - markShared

    @Test func markSharedSetsSignatureOnAnEditableWeek() throws {
        try service.markShared(weekID: "2026-W38", signature: "abc")

        let plan = try #require(try service.plan(for: "2026-W38"))
        #expect(plan.lastSharedSignature == "abc")
    }

    @Test func markSharedIsANoOpOnAnArchivedWeek() throws {
        // No throw, and nothing to update since an archived week's plan (if any) is left alone.
        try service.markShared(weekID: "2026-W37", signature: "abc")
        #expect(try service.plan(for: "2026-W37") == nil)
    }
}
