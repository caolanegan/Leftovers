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
    case archivedSlot(MealSlot)
    case appearanceSettings

    /// Hand-written rather than derived: comparing by `id` (not the models'
    /// own equality) keeps this independent of whichever file happens to
    /// import `SwiftData` in a given incremental build.
    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        switch (lhs, rhs) {
        case (.ingredientLibrary, .ingredientLibrary): true
        case (.ingredient(let a), .ingredient(let b)): a.id == b.id
        case (.meal(let a), .meal(let b)): a.id == b.id
        case (.archivedSlot(let a), .archivedSlot(let b)): a.id == b.id
        case (.appearanceSettings, .appearanceSettings): true
        default: false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .ingredientLibrary:
            hasher.combine(0)
        case .ingredient(let ingredient):
            hasher.combine(1)
            hasher.combine(ingredient.id)
        case .meal(let meal):
            hasher.combine(2)
            hasher.combine(meal.id)
        case .archivedSlot(let slot):
            hasher.combine(3)
            hasher.combine(slot.id)
        case .appearanceSettings:
            hasher.combine(4)
        }
    }
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
            case .archivedSlot(let slot):
                ArchivedSlotDetailView(slot: slot)
            case .appearanceSettings:
                AppearanceSettingsView()
            }
        }
    }
}
