import Foundation

enum QuantityFormatter {
    static func number(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(Int(rounded))
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
        return "\(number(amount)) \(unit.label(for: amount))"
    }

    static func format(amounts: [IngredientUnit: Double]) -> String {
        IngredientUnit.allCases
            .compactMap { unit in amounts[unit].map { format($0, unit: unit) } }
            .joined(separator: " + ")
    }
}
