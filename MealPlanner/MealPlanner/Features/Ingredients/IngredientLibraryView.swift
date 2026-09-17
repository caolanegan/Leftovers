import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "IngredientLibrary")

struct IngredientLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var ingredients: [Ingredient]
    @State private var searchText = ""
    @State private var showingNewIngredient = false
    @State private var pendingDelete: Ingredient?
    @State private var mergeSource: Ingredient?
    @State private var showingMergePicker = false
    @State private var mergeTarget: Ingredient?
    @State private var errorMessage: String?

    private var sortedIngredients: [Ingredient] {
        ingredients.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var filtered: [Ingredient] {
        let key = NameNormalizer.key(searchText)
        guard !key.isEmpty else { return sortedIngredients }
        return sortedIngredients.filter { NameNormalizer.key($0.name).contains(key) }
    }

    private var sections: [(category: ShoppingCategory, items: [Ingredient])] {
        ShoppingCategory.allCases.compactMap { category in
            let items = filtered.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        List {
            ForEach(sections, id: \.category) { section in
                Section(section.category.displayName) {
                    ForEach(section.items) { ingredient in
                        NavigationLink(value: AppRoute.ingredient(ingredient)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ingredient.name)
                                Text(usageCaption(ingredient))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if ingredient.usedInMeals.isEmpty {
                                Button("Delete", role: .destructive) { pendingDelete = ingredient }
                            } else {
                                Button("Merge…") {
                                    mergeSource = ingredient
                                    showingMergePicker = true
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if ingredients.isEmpty {
                ContentUnavailableView(
                    "No Ingredients",
                    systemImage: "carrot",
                    description: Text("Add your first ingredient to get started.")
                )
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Ingredients")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Ingredient", systemImage: "plus") { showingNewIngredient = true }
            }
        }
        .sheet(isPresented: $showingNewIngredient) {
            NavigationStack {
                NewIngredientForm { _ in showingNewIngredient = false }
            }
        }
        .sheet(isPresented: $showingMergePicker) {
            if let mergeSource {
                IngredientPickerSheet(excludedIngredientID: mergeSource.id, showsCreateRow: false) { target in
                    mergeTarget = target
                }
            }
        }
        .confirmationDialog(
            "Merge Ingredients?",
            isPresented: Binding(get: { mergeTarget != nil }, set: { if !$0 { mergeTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Merge", role: .destructive) { performMerge() }
            Button("Cancel", role: .cancel) {
                mergeTarget = nil
                mergeSource = nil
            }
        } message: {
            Text(mergeDialogMessage)
        }
        .sensoryFeedback(.warning, trigger: mergeTarget != nil)
        .confirmationDialog(
            "Delete Ingredient?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(pendingDeleteMessage)
        }
        .sensoryFeedback(.warning, trigger: pendingDelete != nil)
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func usageCaption(_ ingredient: Ingredient) -> String {
        let count = ingredient.usedInMeals.count
        return count == 0 ? "Not used in any meals" : "Used in \(count) meal\(count == 1 ? "" : "s")"
    }

    private var mergeDialogMessage: String {
        guard let mergeSource, let mergeTarget else { return "" }
        return "Merge \"\(mergeSource.name)\" into \"\(mergeTarget.name)\"? Every recipe will use \"\(mergeTarget.name)\". This can't be undone."
    }

    private var pendingDeleteMessage: String {
        guard let pendingDelete else { return "" }
        return "Delete \"\(pendingDelete.name)\"? This can't be undone."
    }

    private func performMerge() {
        guard let mergeSource, let mergeTarget else { return }
        do {
            try IngredientStore(context: modelContext).merge(mergeSource, into: mergeTarget)
        } catch {
            logger.error("Failed to merge ingredient: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
        self.mergeSource = nil
        self.mergeTarget = nil
    }

    private func performDelete() {
        guard let pendingDelete else { return }
        do {
            try IngredientStore(context: modelContext).delete(pendingDelete)
        } catch {
            logger.error("Failed to delete ingredient: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
        self.pendingDelete = nil
    }
}

#Preview {
    NavigationStack {
        IngredientLibraryView()
            .appRouteDestinations()
    }
    .modelContainer(PreviewContainer.shared)
}
