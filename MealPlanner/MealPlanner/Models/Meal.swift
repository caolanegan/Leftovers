import Foundation
import SwiftData

@Model
final class Meal {
    var id: UUID = UUID()
    var name: String = ""
    var isBreakfast: Bool = false
    var isLunch: Bool = false
    var isDinner: Bool = false
    var servings: Int = 2
    var totalMinutes: Int? = nil
    var notes: String = ""
    var isFavorite: Bool = false
    var goodAsLeftovers: Bool = true                              // §7.7: false = never offered as leftovers
    @Attribute(.externalStorage) var photoData: Data? = nil       // JPEG, long edge ≤ 1600 px
    @Attribute(.externalStorage) var thumbnailData: Data? = nil   // JPEG, 300×300
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.meal)
    var ingredients: [RecipeIngredient]? = []
    @Relationship(deleteRule: .cascade, inverse: \InstructionStep.meal)
    var steps: [InstructionStep]? = []
    @Relationship(deleteRule: .nullify, inverse: \MealSlot.meal)
    var slots: [MealSlot]? = []

    init(name: String) {
        self.name = name
    }

    var mealTypes: Set<MealType> {
        get {
            var types: Set<MealType> = []
            if isBreakfast { types.insert(.breakfast) }
            if isLunch { types.insert(.lunch) }
            if isDinner { types.insert(.dinner) }
            return types
        }
        set {
            isBreakfast = newValue.contains(.breakfast)
            isLunch = newValue.contains(.lunch)
            isDinner = newValue.contains(.dinner)
        }
    }

    func suits(_ type: MealType) -> Bool {
        mealTypes.contains(type)
    }

    var sortedIngredients: [RecipeIngredient] {
        (ingredients ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var sortedSteps: [InstructionStep] {
        (steps ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }
}
