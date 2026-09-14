import Testing
import SwiftData
@testable import MealPlanner

@MainActor
struct IngredientStoreTests {
    let container: ModelContainer
    let context: ModelContext
    let store: IngredientStore

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        context = container.mainContext
        store = IngredientStore(context: context)
    }

    @Test func createTrimsAndCollapsesWhitespace() throws {
        let ingredient = try store.create(name: "  Red   Onion ", defaultUnit: .item, category: .produce)
        #expect(ingredient.name == "Red Onion")
    }

    @Test func createWithEmptyNameThrowsInvalidName() throws {
        #expect(throws: AppError.invalidName) {
            try store.create(name: "   ", defaultUnit: .item, category: .produce)
        }
    }

    @Test func createWithDuplicateNameDifferentCaseThrows() throws {
        try store.create(name: "Onion", defaultUnit: .item, category: .produce)

        #expect(throws: AppError.duplicateIngredientName(existingName: "Onion")) {
            try store.create(name: "  onion  ", defaultUnit: .item, category: .produce)
        }
    }

    @Test func updateToADuplicateNameThrowsButKeepingOwnNameDoesNot() throws {
        let onion = try store.create(name: "Onion", defaultUnit: .item, category: .produce)
        try store.create(name: "Garlic", defaultUnit: .clove, category: .produce)

        #expect(throws: AppError.duplicateIngredientName(existingName: "Garlic")) {
            try store.update(onion, name: "garlic", defaultUnit: .item, category: .produce)
        }

        try store.update(onion, name: "Onion", defaultUnit: .kg, category: .produce)
        #expect(onion.defaultUnit == .kg)
    }

    @Test func deletingAnUnusedIngredientSucceeds() throws {
        let onion = try store.create(name: "Onion", defaultUnit: .item, category: .produce)
        try store.delete(onion)
        #expect(try store.all().isEmpty)
    }

    @Test func deletingAnIngredientInUseThrows() throws {
        let onion = try store.create(name: "Onion", defaultUnit: .item, category: .produce)
        let meal = Meal(name: "Soup")
        context.insert(meal)
        let line = RecipeIngredient(ingredient: onion, quantity: 1, unit: .item, note: "", sortIndex: 0)
        line.meal = meal
        context.insert(line)
        try context.save()

        #expect(throws: AppError.ingredientInUse(mealCount: 1)) {
            try store.delete(onion)
        }
    }

    @Test func deletingAnIngredientRemovesItsManualItemsInNonArchivedWeeks() throws {
        let onion = try store.create(name: "Onion", defaultUnit: .item, category: .produce)

        let currentWeek = WeekPlan(weekID: "2026-W38")
        context.insert(currentWeek)
        let currentItem = ManualShoppingItem(ingredient: onion, quantity: 2, unit: .item)
        currentItem.weekPlan = currentWeek
        context.insert(currentItem)

        let endedWeek = WeekPlan(weekID: "2026-W30")
        endedWeek.isArchived = true
        context.insert(endedWeek)
        let archivedItem = ManualShoppingItem(ingredient: onion, quantity: 1, unit: .item)
        archivedItem.weekPlan = endedWeek
        context.insert(archivedItem)

        try context.save()

        try store.delete(onion)

        #expect(currentWeek.manualItems?.isEmpty == true)
        #expect(endedWeek.manualItems?.count == 1)
    }

    @Test func searchRanksPrefixMatchesFirstThenAToZ() throws {
        try store.create(name: "Chorizo", defaultUnit: .g, category: .meatFish)
        try store.create(name: "Chicken breast", defaultUnit: .g, category: .meatFish)
        try store.create(name: "Beef mince", defaultUnit: .g, category: .meatFish)
        try store.create(name: "Rich tea biscuits", defaultUnit: .item, category: .bakery)

        let results = try store.search("ch").map(\.name)
        #expect(results == ["Chicken breast", "Chorizo", "Rich tea biscuits"])
    }

    @Test func findLocatesByNormalizedKey() throws {
        try store.create(name: "Crème Fraîche", defaultUnit: .tbsp, category: .dairyEggs)
        #expect(try store.find(named: "creme fraiche")?.name == "Crème Fraîche")
    }

    @Test func findOrCreateReturnsExistingWithoutDuplicating() throws {
        let first = try store.create(name: "Onion", defaultUnit: .item, category: .produce)
        let found = try store.findOrCreate(name: "onion", defaultUnit: .kg, category: .other)

        #expect(found.id == first.id)
        #expect(try store.all().count == 1)
    }

    @Test func mergeMovesRecipeLinesAndDeletesSource() throws {
        let source = try store.create(name: "Onions", defaultUnit: .item, category: .produce)
        let target = try store.create(name: "Onion", defaultUnit: .item, category: .produce)

        let meal = Meal(name: "Soup")
        context.insert(meal)
        let line = RecipeIngredient(ingredient: source, quantity: 2, unit: .item, note: "", sortIndex: 0)
        line.meal = meal
        context.insert(line)
        try context.save()

        try store.merge(source, into: target)

        #expect(line.ingredient?.id == target.id)
        #expect(try store.find(named: "Onions") == nil)
        #expect(try store.all().map(\.name) == ["Onion"])
    }

    @Test func mergeCombinesManualItemsWithMatchingBaseUnits() throws {
        let source = try store.create(name: "Onions", defaultUnit: .item, category: .produce)
        let target = try store.create(name: "Onion", defaultUnit: .item, category: .produce)

        let plan = WeekPlan(weekID: "2026-W38")
        context.insert(plan)

        let sourceItem = ManualShoppingItem(ingredient: source, quantity: 500, unit: .g)
        sourceItem.weekPlan = plan
        context.insert(sourceItem)

        let targetItem = ManualShoppingItem(ingredient: target, quantity: 0.5, unit: .kg)
        targetItem.weekPlan = plan
        context.insert(targetItem)
        try context.save()

        try store.merge(source, into: target)

        #expect(plan.manualItems?.count == 1)
        #expect(targetItem.quantity == 1)
        #expect(targetItem.unit == .kg)
    }
}
