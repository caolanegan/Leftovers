import Foundation
import SwiftData

@MainActor
enum PreviewContainer {
    static let shared: ModelContainer = {
        do {
            let container = try ModelContainerFactory.make(inMemory: true)
            let mealStore = MealStore(context: container.mainContext)
            try mealStore.addSampleMeals()
            return container
        } catch {
            fatalError("Could not create the preview model container: \(error)")
        }
    }()
}
