import Testing
@testable import MealPlanner

@MainActor
struct IngredientPickerSheetTests {
    @Test func createRowHiddenWhenSearchIsEmpty() {
        let matches = [Ingredient(name: "Onion", defaultUnit: .item, category: .produce)]
        #expect(IngredientPickerSheet.showsCreateRow(searchText: "  ", allowsCreate: true, matches: matches) == false)
    }

    @Test func createRowHiddenWhenCreationNotAllowed() {
        #expect(IngredientPickerSheet.showsCreateRow(searchText: "Chorizo", allowsCreate: false, matches: []) == false)
    }

    @Test func createRowHiddenWhenAnExactNormalizedMatchExists() {
        let matches = [Ingredient(name: "Chorizo", defaultUnit: .item, category: .meatFish)]
        #expect(IngredientPickerSheet.showsCreateRow(searchText: "  chorizo ", allowsCreate: true, matches: matches) == false)
    }

    @Test func createRowShownWhenNoExactMatch() {
        let matches = [Ingredient(name: "Chorizo", defaultUnit: .item, category: .meatFish)]
        #expect(IngredientPickerSheet.showsCreateRow(searchText: "Chicken", allowsCreate: true, matches: matches) == true)
    }

    @Test func createRowShownAgainstAnEmptyLibrary() {
        #expect(IngredientPickerSheet.showsCreateRow(searchText: "Chorizo", allowsCreate: true, matches: []) == true)
    }
}
