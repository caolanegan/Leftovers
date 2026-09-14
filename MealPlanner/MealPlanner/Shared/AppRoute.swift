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
    case meal(Meal)
}

extension View {
    /// - Parameter path: the enclosing `NavigationStack`'s bound path, if it has
    ///   one. `MealDetailView` uses it to replace itself with a duplicated meal
    ///   (§10.5) so Back still returns to the library. Tabs that don't bind a
    ///   path (or don't need that behaviour) can omit it.
    func appRouteDestinations(path: Binding<NavigationPath>? = nil) -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .ingredientLibrary:
                IngredientLibraryView()
            case .ingredient(let ingredient):
                IngredientDetailView(ingredient: ingredient)
            case .meal(let meal):
                MealDetailView(meal: meal, path: path)
            }
        }
    }
}
