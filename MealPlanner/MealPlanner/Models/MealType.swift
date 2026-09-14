import Foundation

enum MealType: String, Codable, CaseIterable, Identifiable, Comparable {
    case breakfast, lunch, dinner

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        }
    }

    var pluralName: String {
        switch self {
        case .breakfast: "Breakfasts"
        case .lunch: "Lunches"
        case .dinner: "Dinners"
        }
    }

    var symbolName: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "moon.stars"
        }
    }

    var sortOrder: Int {
        switch self {
        case .breakfast: 0
        case .lunch: 1
        case .dinner: 2
        }
    }

    static func < (l: Self, r: Self) -> Bool { l.sortOrder < r.sortOrder }
}
