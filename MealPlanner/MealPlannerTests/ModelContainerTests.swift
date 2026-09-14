import Testing
import SwiftData
@testable import MealPlanner

@MainActor
struct ModelContainerTests {
    @Test func savesAndFetchesAMealRecipeIngredientChain() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext

        let ingredient = Ingredient(name: "Onion", defaultUnit: .item, category: .produce)
        context.insert(ingredient)

        let meal = Meal(name: "Tomato soup")
        context.insert(meal)

        let line = RecipeIngredient(ingredient: ingredient, quantity: 1, unit: .item, note: "chopped", sortIndex: 0)
        line.meal = meal
        context.insert(line)

        try context.save()

        let fetchedMeals = try context.fetch(FetchDescriptor<Meal>())
        #expect(fetchedMeals.count == 1)

        let fetchedMeal = try #require(fetchedMeals.first)
        #expect(fetchedMeal.sortedIngredients.count == 1)

        let fetchedLine = try #require(fetchedMeal.sortedIngredients.first)
        #expect(fetchedLine.ingredient?.name == "Onion")
        #expect(fetchedLine.unit == .item)
        #expect(fetchedLine.note == "chopped")

        let fetchedIngredients = try context.fetch(FetchDescriptor<Ingredient>())
        #expect(fetchedIngredients.count == 1)
        #expect(fetchedIngredients.first?.usedInMeals.map(\.name) == ["Tomato soup"])
    }
}
