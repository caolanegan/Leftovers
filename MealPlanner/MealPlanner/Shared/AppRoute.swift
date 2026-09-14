import SwiftUI

/// Every pushable destination in the app, routed by value so each tab's
/// `NavigationStack` declares its destinations exactly once, at the root
/// (via `.appRouteDestinations()`). Screens push with
/// `NavigationLink(value: AppRoute....)` rather than declaring their own
/// `navigationDestination(for:)` — mixing the two on one stack is what caused
/// the M3 bug where tapping an ingredient did nothing.
enum AppRoute: Hashable {
    case ingredientLibrary
    case ingredient(Ingredient)
    // M4 will add: case meal(Meal)
}

extension View {
    func appRouteDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .ingredientLibrary:
                IngredientLibraryView()
            case .ingredient(let ingredient):
                IngredientDetailView(ingredient: ingredient)
            }
        }
    }
}
