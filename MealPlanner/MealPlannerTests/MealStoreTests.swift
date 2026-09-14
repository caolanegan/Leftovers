import Foundation
import Testing
import SwiftData
@testable import MealPlanner

@MainActor
struct MealStoreTests {
    private func makeContext() throws -> ModelContext {
        try ModelContainerFactory.make(inMemory: true).mainContext
    }

    @Test func addSampleMealsAddsEightMealsAndTwentyEightIngredients() throws {
        let context = try makeContext()
        let mealStore = MealStore(context: context)
        let ingredientStore = IngredientStore(context: context)

        let added = try mealStore.addSampleMeals()

        #expect(added == 8)
        #expect(try context.fetch(FetchDescriptor<Meal>()).count == 8)
        #expect(try ingredientStore.all().count == 28)
    }

    @Test func addSampleMealsIsIdempotent() throws {
        let context = try makeContext()
        let mealStore = MealStore(context: context)

        _ = try mealStore.addSampleMeals()
        let secondRun = try mealStore.addSampleMeals()

        #expect(secondRun == 0)
        #expect(try context.fetch(FetchDescriptor<Meal>()).count == 8)
    }

    @Test func createBuildsAMealFromADraft() throws {
        let context = try makeContext()
        let ingredientStore = IngredientStore(context: context)
        let mealStore = MealStore(context: context)
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
        let context = try makeContext()
        let mealStore = MealStore(context: context)

        var draft = MealDraft()
        draft.name = ""
        #expect(throws: AppError.invalidName) {
            try mealStore.create(from: draft)
        }
    }

    @Test func updateReplacesIngredientsAndSteps() throws {
        let context = try makeContext()
        let ingredientStore = IngredientStore(context: context)
        let mealStore = MealStore(context: context)
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
        let context = try makeContext()
        let ingredientStore = IngredientStore(context: context)
        let mealStore = MealStore(context: context)
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
        let context = try makeContext()
        let mealStore = MealStore(context: context)
        var draft = MealDraft()
        draft.name = "Soup"
        let meal = try mealStore.create(from: draft)

        #expect(meal.isFavorite == false)
        try mealStore.toggleFavorite(meal)
        #expect(meal.isFavorite == true)
        try mealStore.toggleFavorite(meal)
        #expect(meal.isFavorite == false)
    }
}
