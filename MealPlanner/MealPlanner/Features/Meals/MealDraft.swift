import Foundation

struct MealDraft: Equatable {
    var name = ""
    var mealTypes: Set<MealType> = [.dinner]
    var servings = 2
    var totalMinutes: Int? = nil
    var notes = ""
    var photo: Data? = nil
    var thumbnail: Data? = nil
    var lines: [RecipeLineDraft] = []
    var steps: [StepDraft] = []

    init() {}

    init(meal: Meal) {
        name = meal.name
        mealTypes = meal.mealTypes
        servings = meal.servings
        totalMinutes = meal.totalMinutes
        notes = meal.notes
        photo = meal.photoData
        thumbnail = meal.thumbnailData
        lines = meal.sortedIngredients.compactMap { line in
            guard let ingredient = line.ingredient else { return nil }
            return RecipeLineDraft(
                id: line.id,
                ingredientID: ingredient.id,
                ingredientName: ingredient.name,
                quantity: line.quantity,
                unit: line.unit,
                note: line.note
            )
        }
        steps = meal.sortedSteps.map { StepDraft(id: $0.id, text: $0.text) }
    }

    var isValid: Bool {
        !NameNormalizer.clean(name).isEmpty && !mealTypes.isEmpty
    }

    func normalized() -> MealDraft {
        var copy = self
        copy.name = NameNormalizer.clean(name)
        return copy
    }
}

struct RecipeLineDraft: Identifiable, Equatable {
    let id: UUID
    var ingredientID: UUID
    var ingredientName: String
    var quantity: Double?
    var unit: IngredientUnit
    var note: String
}

struct StepDraft: Identifiable, Equatable {
    let id: UUID
    var text: String
}
