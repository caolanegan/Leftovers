import Foundation

struct ArchivedIngredientLine: Codable, Equatable, Sendable {
    let name: String
    let amountText: String       // QuantityFormatter output at archive time ("" if none)
    let note: String
}

struct ArchivedSlot: Codable, Equatable, Sendable {
    let slotID: UUID
    let mealID: UUID?
    let mealName: String
    let leftoverOfSlotID: UUID?
    let leftoverSourceLabel: String?          // "Mon dinner"
    let ingredients: [ArchivedIngredientLine] // empty for leftovers
}

/// `ArchivedShoppingList` and the shopping side of archiving arrive in M9,
/// once `ShoppingListBuilder`/`ShoppingCheckEvaluator` exist (§8.1 is read
/// "slots only" for M6).
enum ArchiveCoding {
    static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }
}
