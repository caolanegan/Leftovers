import Foundation

enum AppError: LocalizedError, Equatable {
    case weekIsArchived
    case duplicateIngredientName(existingName: String)
    case ingredientInUse(mealCount: Int)
    case invalidName
    case imageProcessingFailed

    var errorDescription: String? {
        switch self {
        case .weekIsArchived:
            "This week has ended and can't be changed."
        case .duplicateIngredientName(let existingName):
            "An ingredient called \"\(existingName)\" already exists."
        case .ingredientInUse(let mealCount):
            "Used in \(mealCount) meal\(mealCount == 1 ? "" : "s")."
        case .invalidName:
            "Please enter a name."
        case .imageProcessingFailed:
            "That photo couldn't be used. Please try another."
        }
    }
}
