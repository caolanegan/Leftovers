import Foundation

enum QuantityFormatter {
    static func number(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        let rounded = roundedToTwoDecimalPlaces(value)
        if rounded == rounded.rounded() {
            return String(format: "%.0f", rounded)
        }
        var text = String(format: "%.2f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    static func format(_ amount: Double, unit: IngredientUnit) -> String {
        var amount = amount
        var unit = unit
        if unit == .g, amount >= 1000 {
            unit = .kg
            amount /= 1000
        } else if unit == .ml, amount >= 1000 {
            unit = .l
            amount /= 1000
        }

        if unit == .item {
            return number(amount)
        }
        return "\(number(amount)) \(unit.label(for: roundedToTwoDecimalPlaces(amount)))"
    }

    static func format(amounts: [IngredientUnit: Double]) -> String {
        IngredientUnit.allCases
            .compactMap { unit in amounts[unit].map { format($0, unit: unit) } }
            .joined(separator: " + ")
    }

    private static func roundedToTwoDecimalPlaces(_ value: Double) -> Double {
        guard value.isFinite else { return value }
        return (value * 100).rounded() / 100
    }
}
