import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "MealLibrary")

private enum MealSortOption: String, CaseIterable, Identifiable {
    case alphabetical, recentlyAdded, favouritesFirst

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alphabetical: "A–Z"
        case .recentlyAdded: "Recently Added"
        case .favouritesFirst: "Favourites First"
        }
    }
}

struct MealLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var meals: [Meal]
    @State private var searchText = ""
    @State private var typeFilter: MealType?
    @AppStorage("mealSort") private var sortOption = MealSortOption.alphabetical
    @State private var showingNewMeal = false
    @State private var pendingDelete: Meal?
    @State private var errorMessage: String?

    private var filtered: [Meal] {
        var result = meals
        if let typeFilter { result = result.filter { $0.suits(typeFilter) } }

        let key = NameNormalizer.key(searchText)
        if !key.isEmpty {
            result = result.filter { meal in
                NameNormalizer.key(meal.name).contains(key)
                    || meal.sortedIngredients.contains { NameNormalizer.key($0.ingredient?.name ?? "").contains(key) }
            }
        }
        return sorted(result)
    }

    var body: some View {
        List {
            Picker("Type", selection: $typeFilter) {
                Text("All").tag(MealType?.none)
                ForEach(MealType.allCases) { type in
                    Text(type.displayName).tag(MealType?.some(type))
                }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            ForEach(filtered) { meal in
                NavigationLink(value: AppRoute.meal(meal)) {
                    MealRow(meal: meal)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        toggleFavorite(meal)
                    } label: {
                        Label(meal.isFavorite ? "Unfavourite" : "Favourite", systemImage: meal.isFavorite ? "star.slash" : "star")
                    }
                    .tint(.yellow)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) { pendingDelete = meal }
                }
            }
        }
        .overlay {
            if meals.isEmpty {
                ContentUnavailableView {
                    Label("No Meals Yet", systemImage: "fork.knife")
                } description: {
                    Text("Add your first meal to get started.")
                } actions: {
                    Button("Add Meal") { showingNewMeal = true }
                    Button("Add Example Meals") { addSampleMeals() }
                }
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Search meals or ingredients")
        .navigationTitle("Meals")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: AppRoute.ingredientLibrary) {
                    Image(systemName: "carrot")
                }
                .accessibilityLabel("Ingredients")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(MealSortOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewMeal = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Meal")
            }
        }
        .sheet(isPresented: $showingNewMeal) {
            MealEditorView()
        }
        .confirmationDialog(
            pendingDelete.map { "Delete \"\($0.name)\"?" } ?? "",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(pendingDeleteMessage)
        }
        .sensoryFeedback(trigger: pendingDelete != nil) { _, shown in shown ? .warning : nil }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func sorted(_ meals: [Meal]) -> [Meal] {
        switch sortOption {
        case .alphabetical:
            return meals.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .recentlyAdded:
            return meals.sorted { $0.createdAt > $1.createdAt }
        case .favouritesFirst:
            return meals.sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private var pendingDeleteMessage: String {
        guard let pendingDelete else { return "" }
        let count = MealStore(context: modelContext).upcomingPlanCount(for: pendingDelete)
        var sentences: [String] = []
        if count > 0 {
            sentences.append("It's planned \(count) time\(count == 1 ? "" : "s") in this and upcoming weeks and will be removed from those plans.")
        }
        sentences.append("Past weeks won't change.")
        sentences.append("This can't be undone.")
        return sentences.joined(separator: " ")
    }

    private func toggleFavorite(_ meal: Meal) {
        do {
            try MealStore(context: modelContext).toggleFavorite(meal)
        } catch {
            logger.error("Failed to toggle favourite: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }

    private func addSampleMeals() {
        do {
            try MealStore(context: modelContext).addSampleMeals()
        } catch {
            logger.error("Failed to add sample meals: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }

    private func performDelete() {
        guard let pendingDelete else { return }
        do {
            try MealStore(context: modelContext).delete(pendingDelete)
        } catch {
            logger.error("Failed to delete meal: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
        self.pendingDelete = nil
    }
}

#Preview {
    NavigationStack {
        MealLibraryView()
            .appRouteDestinations()
    }
    .modelContainer(PreviewContainer.shared)
}
