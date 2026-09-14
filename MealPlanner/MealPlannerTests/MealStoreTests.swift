import Foundation
import Testing
import SwiftData
@testable import MealPlanner

@MainActor
struct MealStoreTests {
    let container: ModelContainer
    let context: ModelContext
    let mealStore: MealStore
    let ingredientStore: IngredientStore

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        context = container.mainContext
        mealStore = MealStore(context: context)
        ingredientStore = IngredientStore(context: context)
    }

    @Test func addSampleMealsAddsEightMealsAndTwentyEightIngredients() throws {
        let added = try mealStore.addSampleMeals()

        #expect(added == 8)
        #expect(try context.fetch(FetchDescriptor<Meal>()).count == 8)
        #expect(try ingredientStore.all().count == 28)
    }

    @Test func addSampleMealsIsIdempotent() throws {
        _ = try mealStore.addSampleMeals()
        let secondRun = try mealStore.addSampleMeals()

        #expect(secondRun == 0)
        #expect(try context.fetch(FetchDescriptor<Meal>()).count == 8)
    }

    @Test func createBuildsAMealFromADraft() throws {
        let onion = try ingredientStore.create(name: "Onion", defaultUnit: .item, category: .produce)

        var draft = MealDraft()
        draft.name = "  Tomato soup "
        draft.mealTypes = [.lunch, .dinner]
        draft.servings = 4
        draft.lines = [
            RecipeLineDraft(id: UUID(), ingredientID: onion.id, ingredientName: onion.name, quantity: 1, unit: .item, note: "chopped"),
        ]
        draft.steps = [StepDraft(id: UUID(), text: "Simmer.")]

        let meal = try mealStore.create(from: draft)

        #expect(meal.name == "Tomato soup")
        #expect(meal.mealTypes == [.lunch, .dinner])
        #expect(meal.sortedIngredients.map(\.ingredient?.name) == ["Onion"])
        #expect(meal.sortedSteps.map(\.text) == ["Simmer."])
    }

    @Test func createWithInvalidDraftThrows() throws {
        var draft = MealDraft()
        draft.name = ""
        #expect(throws: AppError.invalidName) {
            try mealStore.create(from: draft)
        }
    }

    @Test func updateReplacesIngredientsAndSteps() throws {
        let onion = try ingredientStore.create(name: "Onion", defaultUnit: .item, category: .produce)
        let garlic = try ingredientStore.create(name: "Garlic", defaultUnit: .clove, category: .produce)

        var draft = MealDraft()
        draft.name = "Soup"
        draft.lines = [RecipeLineDraft(id: UUID(), ingredientID: onion.id, ingredientName: onion.name, quantity: 1, unit: .item, note: "")]
        let meal = try mealStore.create(from: draft)

        draft.lines = [RecipeLineDraft(id: UUID(), ingredientID: garlic.id, ingredientName: garlic.name, quantity: 2, unit: .clove, note: "")]
        draft.steps = [StepDraft(id: UUID(), text: "Cook it.")]
        try mealStore.update(meal, from: draft)

        #expect(meal.sortedIngredients.map(\.ingredient?.name) == ["Garlic"])
        #expect(meal.sortedSteps.map(\.text) == ["Cook it."])
    }

    @Test func duplicateCopiesFieldsAndResetsFavorite() throws {
        let onion = try ingredientStore.create(name: "Onion", defaultUnit: .item, category: .produce)

        var draft = MealDraft()
        draft.name = "Soup"
        draft.lines = [RecipeLineDraft(id: UUID(), ingredientID: onion.id, ingredientName: onion.name, quantity: 1, unit: .item, note: "")]
        let meal = try mealStore.create(from: draft)
        try mealStore.toggleFavorite(meal)

        let copy = try mealStore.duplicate(meal)

        #expect(copy.name == "Soup (copy)")
        #expect(copy.isFavorite == false)
        #expect(copy.sortedIngredients.map(\.ingredient?.name) == ["Onion"])
        #expect(meal.isFavorite == true)
    }

    @Test func toggleFavoriteFlipsTheFlag() throws {
        var draft = MealDraft()
        draft.name = "Soup"
        let meal = try mealStore.create(from: draft)

        #expect(meal.isFavorite == false)
        try mealStore.toggleFavorite(meal)
        #expect(meal.isFavorite == true)
        try mealStore.toggleFavorite(meal)
        #expect(meal.isFavorite == false)
    }

    @Test func upcomingPlanCountCountsOnlyNonArchivedSlots() throws {
        var draft = MealDraft()
        draft.name = "Soup"
        let meal = try mealStore.create(from: draft)

        let currentWeek = WeekPlan(weekID: "2026-W38")
        let archivedWeek = WeekPlan(weekID: "2026-W37")
        archivedWeek.isArchived = true
        context.insert(currentWeek)
        context.insert(archivedWeek)

        let currentSlot = MealSlot(dayIndex: 0, mealType: .dinner)
        currentSlot.weekPlan = currentWeek
        currentSlot.meal = meal
        let archivedSlot = MealSlot(dayIndex: 0, mealType: .dinner)
        archivedSlot.weekPlan = archivedWeek
        archivedSlot.meal = meal
        context.insert(currentSlot)
        context.insert(archivedSlot)
        try context.save()

        #expect(mealStore.upcomingPlanCount(for: meal) == 1)
    }
}
