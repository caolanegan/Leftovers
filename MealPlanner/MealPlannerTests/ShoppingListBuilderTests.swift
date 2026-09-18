import Foundation
import Testing
@testable import Leftovers

@MainActor
struct ShoppingListBuilderTests {
    private let keyA = UUID().uuidString
    private let keyB = UUID().uuidString

    private func line(
        key: String, name: String = "Ingredient", category: ShoppingCategory = .produce,
        quantity: Double?, unit: IngredientUnit, source: ShoppingLineSource = .meal("Meal")
    ) -> ShoppingLine {
        ShoppingLine(ingredientKey: key, name: name, category: category, quantity: quantity, unit: unit, source: source)
    }

    @Test func sameIngredientFromTwoMealsMergesAndListsBothUsedIn() {
        let lines = [
            line(key: keyA, name: "Chicken", category: .meatFish, quantity: 200, unit: .g, source: .meal("Fajitas")),
            line(key: keyA, name: "Chicken", category: .meatFish, quantity: 0.3, unit: .kg, source: .meal("Wrap")),
        ]

        let sections = ShoppingListBuilder.build(from: lines)

        let item = try! #require(sections.first?.items.first)
        #expect(item.amounts == [.g: 500])
        #expect(item.usedIn == ["Fajitas", "Wrap"])
    }

    @Test func sameNameDifferentKeysNeverMerge() {
        let lines = [
            line(key: keyA, name: "Onion", quantity: 1, unit: .item),
            line(key: keyB, name: "Onion", quantity: 2, unit: .item),
        ]

        let sections = ShoppingListBuilder.build(from: lines)

        #expect(sections.first?.items.count == 2)
    }

    @Test func unquantifiedLineContributesNoAmount() {
        let lines = [
            line(key: keyA, name: "Garlic", quantity: 2, unit: .clove),
            line(key: keyA, name: "Garlic", quantity: nil, unit: .clove),
        ]

        let sections = ShoppingListBuilder.build(from: lines)

        #expect(sections.first?.items.first?.amounts == [.clove: 2])
    }

    @Test func mlAndLCombineInBaseUnit() {
        let lines = [
            line(key: keyA, name: "Milk", quantity: 500, unit: .ml),
            line(key: keyA, name: "Milk", quantity: 1, unit: .l),
        ]

        let sections = ShoppingListBuilder.build(from: lines)

        #expect(sections.first?.items.first?.amounts == [.ml: 1500])
    }

    @Test func onlyUnquantifiedLineProducesEmptyAmounts() {
        let sections = ShoppingListBuilder.build(from: [line(key: keyA, name: "Salt", quantity: nil, unit: .item)])

        #expect(sections.first?.items.first?.amounts == [:])
    }

    @Test func sameMealCookedTwiceDoublesTheAmountButNotUsedIn() {
        let lines = [
            line(key: keyA, name: "Oats", quantity: 50, unit: .g, source: .meal("Porridge")),
            line(key: keyA, name: "Oats", quantity: 50, unit: .g, source: .meal("Porridge")),
        ]

        let sections = ShoppingListBuilder.build(from: lines)

        let item = try! #require(sections.first?.items.first)
        #expect(item.amounts == [.g: 100])
        #expect(item.usedIn == ["Porridge"])
    }

    @Test func mealAndManualLinesCombineAndFlagHasManualEntry() {
        let lines = [
            line(key: keyA, name: "Rice", quantity: 250, unit: .g, source: .meal("Curry")),
            line(key: keyA, name: "Rice", quantity: 1, unit: .pack, source: .manual),
        ]

        let sections = ShoppingListBuilder.build(from: lines)

        let item = try! #require(sections.first?.items.first)
        #expect(item.amounts == [.g: 250, .pack: 1])
        #expect(item.hasManualEntry == true)
    }

    @Test func manualOnlyItemHasEmptyUsedIn() {
        let sections = ShoppingListBuilder.build(from: [
            line(key: keyA, name: "Toilet roll", category: .household, quantity: 1, unit: .pack, source: .manual),
        ])

        let item = try! #require(sections.first?.items.first)
        #expect(item.usedIn == [])
        #expect(item.hasManualEntry == true)
    }

    @Test func sectionsFollowCategoryDeclarationOrderAndSkipEmptyOnes() {
        let lines = [
            line(key: UUID().uuidString, name: "Bread", category: .bakery, quantity: 1, unit: .item),
            line(key: UUID().uuidString, name: "Onion", category: .produce, quantity: 1, unit: .item),
        ]

        let sections = ShoppingListBuilder.build(from: lines)

        #expect(sections.map(\.category) == [.produce, .bakery])
    }

    @Test func itemsWithinASectionAreSortedByName() {
        let lines = [
            line(key: UUID().uuidString, name: "Potato", category: .produce, quantity: 1, unit: .item),
            line(key: UUID().uuidString, name: "Apple", category: .produce, quantity: 1, unit: .item),
        ]

        let sections = ShoppingListBuilder.build(from: lines)

        #expect(sections.first?.items.map(\.displayName) == ["Apple", "Potato"])
    }

    @Test func signatureIsDeterministicAndChangesWithAmountOrManualFlag() {
        let base = ShoppingListBuilder.build(from: [line(key: keyA, name: "Rice", quantity: 250, unit: .g)])
        let changedAmount = ShoppingListBuilder.build(from: [line(key: keyA, name: "Rice", quantity: 300, unit: .g)])
        let addedManual = ShoppingListBuilder.build(from: [
            line(key: keyA, name: "Rice", quantity: 250, unit: .g),
            line(key: keyA, name: "Rice", quantity: 1, unit: .pack, source: .manual),
        ])

        #expect(ShoppingListBuilder.signature(of: base) == ShoppingListBuilder.signature(of: base))
        #expect(ShoppingListBuilder.signature(of: base) != ShoppingListBuilder.signature(of: changedAmount))
        #expect(ShoppingListBuilder.signature(of: base) != ShoppingListBuilder.signature(of: addedManual))
    }
}
