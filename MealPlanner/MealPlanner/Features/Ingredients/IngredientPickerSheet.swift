import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "IngredientPicker")

/// Shared search-and-pick sheet for choosing a library ingredient. Reused for
/// adding a recipe line (M4), adding a hand-added shopping item (M9) and
/// merging (M3, with `showsCreateRow: false`).
struct IngredientPickerSheet: View {
    var excludedIngredientID: UUID?
    var showsCreateRow: Bool = true
    var onSelect: (Ingredient) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [Ingredient] = []
    @FocusState private var searchFieldFocused: Bool

    private var visibleResults: [Ingredient] {
        guard let excludedIngredientID else { return results }
        return results.filter { $0.id != excludedIngredientID }
    }

    private var showsCreateRowNow: Bool {
        Self.showsCreateRow(searchText: searchText, allowsCreate: showsCreateRow, matches: visibleResults)
    }

    var body: some View {
        NavigationStack {
            List {
                if showsCreateRowNow {
                    NavigationLink {
                        NewIngredientForm(prefilledName: searchText, showsCancelButton: false) { ingredient in
                            onSelect(ingredient)
                            dismiss()
                        }
                    } label: {
                        Label("Create \"\(NameNormalizer.clean(searchText))\"", systemImage: "plus")
                    }
                }
                ForEach(visibleResults) { ingredient in
                    Button {
                        onSelect(ingredient)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ingredient.name)
                                .foregroundStyle(.primary)
                            Text(ingredient.category.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
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
}

#Preview {
    IngredientPickerSheet { _ in }
        .modelContainer(PreviewContainer.shared)
}
