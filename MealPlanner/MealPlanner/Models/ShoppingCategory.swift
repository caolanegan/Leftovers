import Foundation

enum ShoppingCategory: String, Codable, CaseIterable, Identifiable {
    // Declaration order == display order
    case produce, meatFish, dairyEggs, bakery, pantry, frozen, drinks, household, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .produce: "Fruit & Veg"
        case .meatFish: "Meat & Fish"
        case .dairyEggs: "Dairy & Eggs"
        case .bakery: "Bakery"
        case .pantry: "Food Cupboard"
        case .frozen: "Frozen"
        case .drinks: "Drinks"
        case .household: "Household"
        case .other: "Other"
        }
    }
}
