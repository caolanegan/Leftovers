import SwiftUI

/// Meal-type and aisle colours and symbols (§13.5). Kept as SwiftUI
/// extensions on the `Models/` enums, rather than properties on the enums
/// themselves, so `Models/` and `Domain/` stay free of SwiftUI imports.
extension MealType {
    var tint: Color {
        switch self {
        case .breakfast: .orange
        case .lunch: .teal
        case .dinner: .indigo
        }
    }
}

extension ShoppingCategory {
    var symbolName: String {
        switch self {
        case .produce: "carrot"
        case .meatFish: "fish"
        case .dairyEggs: "cup.and.saucer"
        case .bakery: "birthday.cake"
        case .pantry: "cabinet"
        case .frozen: "snowflake"
        case .drinks: "wineglass"
        case .household: "house"
        case .other: "basket"
        }
    }

    var tint: Color {
        switch self {
        case .produce: .green
        case .meatFish: .red
        case .dairyEggs: .blue
        case .bakery: .brown
        case .pantry: .orange
        case .frozen: .cyan
        case .drinks: .purple
        case .household: .indigo
        case .other: .gray
        }
    }
}
