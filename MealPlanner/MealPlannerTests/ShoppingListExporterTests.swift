import Foundation
import Testing
@testable import Leftovers

@MainActor
struct ShoppingListExporterTests {
    private func item(
        key: String = UUID().uuidString, name: String, category: ShoppingCategory,
        amounts: [IngredientUnit: Double] = [:], usedIn: [String] = [], hasManualEntry: Bool = false
    ) -> ShoppingListItem {
        ShoppingListItem(key: key, displayName: name, category: category, amounts: amounts, usedIn: usedIn, hasManualEntry: hasManualEntry)
    }

    /// §7.9's worked example, tested for the exact string.
    @Test func exactStringFromSpec() {
        let garlic = item(key: "garlic", name: "Garlic", category: .produce, amounts: [.clove: 2])
        let onion = item(key: "onion", name: "Onion", category: .produce, amounts: [.item: 3])
        let chicken = item(key: "chicken", name: "Chicken breast", category: .meatFish, amounts: [.g: 350])
        let oil = item(key: "oil", name: "Olive oil", category: .pantry)
        let salt = item(key: "salt", name: "Salt", category: .pantry)
        let toiletRoll = item(key: "toiletRoll", name: "Toilet roll", category: .household, amounts: [.pack: 1])

        let sections = [
            ShoppingListSection(category: .produce, items: [garlic, onion]),
            ShoppingListSection(category: .meatFish, items: [chicken]),
            ShoppingListSection(category: .pantry, items: [oil, salt]),
            ShoppingListSection(category: .household, items: [toiletRoll]),
        ]
        let statuses: [String: CheckStatus] = [
            "garlic": .unchecked,
            "onion": .unchecked,
            "chicken": .needsMore([.g: 200]),
            "oil": .unchecked,
            "salt": .checked,
            "toiletRoll": .unchecked,
        ]
        let mealPlan = [
            ExportDay(dayIndex: 0, meals: [ExportMeal(name: "Overnight oats", isLeftovers: false), ExportMeal(name: "Chicken fajitas", isLeftovers: false)]),
            ExportDay(dayIndex: 1, meals: [ExportMeal(name: "Chicken fajitas", isLeftovers: true)]),
        ]

        let text = ShoppingListExporter.text(
            weekCommencing: "w/c 14 Sep", sections: sections, statuses: statuses, mealPlan: mealPlan,
            options: ExportOptions(includeChecked: true, includeMealPlan: true)
        )

        let expected = """
        *Shopping list · w/c 14 Sep*

        *Fruit & Veg*
        • Garlic – 2 cloves
        • Onion – 3

        *Meat & Fish*
        • Chicken breast – 200 g more

        *Food Cupboard*
        • Olive oil
        ✓ Salt

        *Household*
        • Toilet roll – 1 pack

        *Meals*
        Mon: Overnight oats, Chicken fajitas
        Tue: Chicken fajitas (leftovers)
        """
        #expect(text == expected)
        #expect(!text.hasSuffix("\n"))
    }

    @Test func checkedItemsAreOmittedWhenNotIncluded() {
        let sections = [ShoppingListSection(category: .produce, items: [
            item(key: "a", name: "Garlic", category: .produce, amounts: [.clove: 2]),
            item(key: "b", name: "Onion", category: .produce, amounts: [.item: 3]),
        ])]
        let statuses: [String: CheckStatus] = ["a": .unchecked, "b": .checked]

        let text = ShoppingListExporter.text(
            weekCommencing: "w/c 14 Sep", sections: sections, statuses: statuses, mealPlan: [],
            options: ExportOptions(includeChecked: false, includeMealPlan: false)
        )

        #expect(text == "*Shopping list · w/c 14 Sep*\n\n*Fruit & Veg*\n• Garlic – 2 cloves")
    }

    @Test func sectionThatBecomesEmptyAfterHidingCheckedItemsIsDropped() {
        let sections = [ShoppingListSection(category: .produce, items: [item(key: "a", name: "Garlic", category: .produce)])]
        let statuses: [String: CheckStatus] = ["a": .checked]

        let text = ShoppingListExporter.text(
            weekCommencing: "w/c 14 Sep", sections: sections, statuses: statuses, mealPlan: [],
            options: ExportOptions(includeChecked: false, includeMealPlan: false)
        )

        #expect(text == "*Shopping list · w/c 14 Sep*")
    }

    @Test func mealPlanOmittedWhenOptionIsOff() {
        let sections = [ShoppingListSection(category: .produce, items: [item(key: "a", name: "Garlic", category: .produce)])]
        let mealPlan = [ExportDay(dayIndex: 0, meals: [ExportMeal(name: "Bolognese", isLeftovers: false)])]

        let text = ShoppingListExporter.text(
            weekCommencing: "w/c 14 Sep", sections: sections, statuses: ["a": .unchecked], mealPlan: mealPlan,
            options: ExportOptions(includeChecked: false, includeMealPlan: false)
        )

        #expect(!text.contains("*Meals*"))
    }

    @Test func mealPlanOmittedWhenNoDayHasMeals() {
        let sections = [ShoppingListSection(category: .produce, items: [item(key: "a", name: "Garlic", category: .produce)])]

        let text = ShoppingListExporter.text(
            weekCommencing: "w/c 14 Sep", sections: sections, statuses: ["a": .unchecked], mealPlan: [],
            options: ExportOptions(includeChecked: false, includeMealPlan: true)
        )

        #expect(!text.contains("*Meals*"))
    }

    @Test func hasExportableItemsIsFalseWhenEverythingIsCheckedAndHidden() {
        let sections = [ShoppingListSection(category: .produce, items: [item(key: "a", name: "Garlic", category: .produce)])]

        #expect(!ShoppingListExporter.hasExportableItems(sections: sections, statuses: ["a": .checked], options: ExportOptions(includeChecked: false, includeMealPlan: true)))
        #expect(ShoppingListExporter.hasExportableItems(sections: sections, statuses: ["a": .checked], options: ExportOptions(includeChecked: true, includeMealPlan: true)))
    }

    @Test func hasExportableItemsIsFalseForEmptySections() {
        #expect(!ShoppingListExporter.hasExportableItems(sections: [], statuses: [:], options: ExportOptions()))
    }
}
