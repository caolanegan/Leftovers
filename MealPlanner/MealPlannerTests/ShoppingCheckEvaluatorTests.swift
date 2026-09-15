import Foundation
import Testing
@testable import MealPlanner

@MainActor
struct ShoppingCheckEvaluatorTests {
    private func item(amounts: [IngredientUnit: Double]) -> ShoppingListItem {
        ShoppingListItem(key: "k", displayName: "Chicken breast", category: .meatFish, amounts: amounts, usedIn: [], hasManualEntry: false)
    }

    @Test func uncheckedOrNilIsUnchecked() {
        #expect(ShoppingCheckEvaluator.status(for: item(amounts: [.g: 200]), isChecked: nil, checkedAmounts: [:]) == .unchecked)
        #expect(ShoppingCheckEvaluator.status(for: item(amounts: [.g: 200]), isChecked: false, checkedAmounts: [.g: 200]) == .unchecked)
    }

    @Test func sameAmountStaysChecked() {
        let status = ShoppingCheckEvaluator.status(for: item(amounts: [.g: 200]), isChecked: true, checkedAmounts: [.g: 200])
        #expect(status == .checked)
    }

    @Test func needingMoreSurfacesTheExtra() {
        let status = ShoppingCheckEvaluator.status(for: item(amounts: [.g: 400]), isChecked: true, checkedAmounts: [.g: 200])
        #expect(status == .needsMore([.g: 200]))
    }

    @Test func needingLessStaysChecked() {
        let status = ShoppingCheckEvaluator.status(for: item(amounts: [.g: 200]), isChecked: true, checkedAmounts: [.g: 400])
        #expect(status == .checked)
    }

    @Test func newUnitNotPreviouslyCheckedNeedsMoreOnlyForThatUnit() {
        let status = ShoppingCheckEvaluator.status(for: item(amounts: [.g: 200, .pack: 1]), isChecked: true, checkedAmounts: [.g: 200])
        #expect(status == .needsMore([.pack: 1]))
    }

    @Test func unquantifiedAndTickedIsChecked() {
        let status = ShoppingCheckEvaluator.status(for: item(amounts: [:]), isChecked: true, checkedAmounts: [:])
        #expect(status == .checked)
    }
}
