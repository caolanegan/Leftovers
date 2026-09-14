import Foundation

enum IngredientUnit: String, Codable, CodingKeyRepresentable, CaseIterable, Identifiable {
    // Declaration order == picker order == order when joining amounts
    case item, g, kg, ml, l, tsp, tbsp, cup, clove, slice, tin, pack, bunch, handful, pinch

    var id: String { rawValue }

    var baseUnit: IngredientUnit {
        switch self {
        case .kg: .g
        case .l: .ml
        default: self
        }
    }

    var toBaseMultiplier: Double {
        switch self {
        case .kg, .l: 1000
        default: 1
        }
    }

    var pickerLabel: String {
        self == .item ? "item (whole)" : rawValue
    }

    var hasPlural: Bool {
        switch self {
        case .cup, .clove, .slice, .tin, .pack, .bunch, .handful, .pinch: true
        default: false
        }
    }

    private var pluralForm: String {
        switch self {
        case .cup: "cups"
        case .clove: "cloves"
        case .slice: "slices"
        case .tin: "tins"
        case .pack: "packs"
        case .bunch: "bunches"
        case .handful: "handfuls"
        case .pinch: "pinches"
        default: rawValue
        }
    }

    func label(for amount: Double) -> String {
        guard self != .item else { return "" }
        guard hasPlural, amount != 1 else { return rawValue }
        return pluralForm
    }
}
