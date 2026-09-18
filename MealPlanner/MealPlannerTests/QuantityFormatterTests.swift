import Testing
@testable import Leftovers

@MainActor
struct QuantityFormatterTests {
    @Test(arguments: [
        (400.0, IngredientUnit.g, "400 g"),
        (1500.0, IngredientUnit.g, "1.5 kg"),
        (1000.0, IngredientUnit.ml, "1 l"),
        (0.3, IngredientUnit.kg, "0.3 kg"),
        (1.0 / 3.0, IngredientUnit.tsp, "0.33 tsp"),
        (3.0, IngredientUnit.item, "3"),
        (1.0, IngredientUnit.tin, "1 tin"),
        (2.0, IngredientUnit.bunch, "2 bunches"),
    ])
    func formatsAmount(amount: Double, unit: IngredientUnit, expected: String) {
        #expect(QuantityFormatter.format(amount, unit: unit) == expected)
    }

    @Test func formatsSingularWhenTheAmountRoundsToOne() {
        #expect(QuantityFormatter.format(1.001, unit: .tin) == "1 tin")
    }

    @Test func formatsAJoinedAmountsDictionary() {
        #expect(QuantityFormatter.format(amounts: [.g: 200, .item: 2]) == "2 + 200 g")
    }

    @Test func formatsAnEmptyAmountsDictionaryAsEmptyString() {
        #expect(QuantityFormatter.format(amounts: [:]) == "")
    }

    @Test(arguments: [
        (400.0, "400"),
        (1.5, "1.5"),
        (1.0 / 3.0, "0.33"),
        (0.3, "0.3"),
        (2.0, "2"),
    ])
    func formatsNumber(value: Double, expected: String) {
        #expect(QuantityFormatter.number(value) == expected)
    }
}
