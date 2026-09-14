import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "IngredientPicker")

/// Shared search-and-pick sheet for choosing a library ingredient. Reused for
/// adding a recipe line (M4), adding a hand-added shopping item (M9) and
/// merging (M3, with `showsCreateRow: false`).
struct IngredientPickerSheet: View {
    /// Wires this sheet into the "add ingredient to a recipe" flow (§10.7):
    /// picking or creating an ingredient pushes into `RecipeIngredientForm`
    /// (step 2) instead of calling `onSelect` and dismissing. Merge (M3) and
    /// the shopping "+" (M9) leave `recipeCompletion` nil and use `onSelect`.
    struct RecipeCompletion {
        var onAdd: (RecipeLineDraft) -> Void
        var onFinish: () -> Void
    }

    var excludedIngredientID: UUID?
    var showsCreateRow: Bool = true
    var recipeCompletion: RecipeCompletion? = nil
    var onSelect: (Ingredient) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [Ingredient] = []
    @State private var path = NavigationPath()
    @FocusState private var searchFieldFocused: Bool

    private var visibleResults: [Ingredient] {
        guard let excludedIngredientID else { return results }
        return results.filter { $0.id != excludedIngredientID }
    }

    private var showsCreateRowNow: Bool {
        Self.showsCreateRow(searchText: searchText, allowsCreate: showsCreateRow, matches: visibleResults)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if showsCreateRowNow {
                    NavigationLink(value: Route.create(searchText)) {
                        Label("Create \"\(NameNormalizer.clean(searchText))\"", systemImage: "plus")
                    }
                }
                ForEach(visibleResults) { ingredient in
                    row(for: ingredient)
                }
            }
            .overlay {
                if visibleResults.isEmpty, !showsCreateRowNow, NameNormalizer.key(searchText).isEmpty {
                    ContentUnavailableView(
                        "Empty Library",
                        systemImage: "carrot",
                        description: Text("Your ingredient library is empty. Type a name to create one.")
                    )
                }
            }
            .searchable(text: $searchText)
            .searchFocused($searchFieldFocused)
            .onAppear {
                refresh()
                searchFieldFocused = true
            }
            .onChange(of: searchText) { refresh() }
            .navigationTitle("Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .create(let prefill):
                    NewIngredientForm(prefilledName: prefill, showsCancelButton: false) { ingredient in
                        handlePicked(ingredient)
                    }
                case .recipeForm(let ingredient):
                    RecipeIngredientForm(
                        ingredient: ingredient,
                        mode: .add(
                            onAdd: { line in
                                recipeCompletion?.onAdd(line)
                                recipeCompletion?.onFinish()
                            },
                            onAddAndNext: { line in
                                recipeCompletion?.onAdd(line)
                                path.removeLast()
                                searchText = ""
                            }
                        )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func row(for ingredient: Ingredient) -> some View {
        if recipeCompletion != nil {
            NavigationLink(value: Route.recipeForm(ingredient)) {
                ingredientLabel(ingredient)
            }
        } else {
            Button {
                onSelect(ingredient)
                dismiss()
            } label: {
                ingredientLabel(ingredient)
            }
            .buttonStyle(.plain)
        }
    }

    private func ingredientLabel(_ ingredient: Ingredient) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ingredient.name)
                .foregroundStyle(.primary)
            Text(ingredient.category.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func handlePicked(_ ingredient: Ingredient) {
        if recipeCompletion != nil {
            path.removeLast()
            path.append(Route.recipeForm(ingredient))
        } else {
            onSelect(ingredient)
            dismiss()
        }
    }

    private func refresh() {
        do {
            results = try IngredientStore(context: modelContext).search(searchText)
        } catch {
            logger.error("Failed to search ingredients: \(error, privacy: .public)")
            results = []
        }
    }

    /// Pure decision used by the view above, and directly unit-tested:
    /// the row only appears when creation is allowed, there's search text,
    /// and nothing in `matches` has an exact (normalized) name match.
    static func showsCreateRow(searchText: String, allowsCreate: Bool, matches: [Ingredient]) -> Bool {
        guard allowsCreate else { return false }
        let key = NameNormalizer.key(searchText)
        guard !key.isEmpty else { return false }
        return !matches.contains { NameNormalizer.key($0.name) == key }
    }

    private enum Route: Hashable {
        case create(String)
        case recipeForm(Ingredient)
    }
}

#Preview {
    IngredientPickerSheet { _ in }
        .modelContainer(PreviewContainer.shared)
}
