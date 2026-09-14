import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "IngredientDetail")

struct IngredientDetailView: View {
    let ingredient: Ingredient

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var defaultUnit: IngredientUnit
    @State private var category: ShoppingCategory
    @State private var duplicateName: String?
    @State private var errorMessage: String?
    @State private var showingMergePicker = false
    @State private var mergeTarget: Ingredient?
    @State private var showingDeleteConfirmation = false

    init(ingredient: Ingredient) {
        self.ingredient = ingredient
        _name = State(initialValue: ingredient.name)
        _defaultUnit = State(initialValue: ingredient.defaultUnit)
        _category = State(initialValue: ingredient.category)
    }

    private var mealsUsingIngredient: [Meal] { ingredient.usedInMeals }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                Picker("Default Unit", selection: $defaultUnit) {
                    ForEach(IngredientUnit.allCases) { unit in
                        Text(unit.pickerLabel).tag(unit)
                    }
                }
                Picker("Aisle", selection: $category) {
                    ForEach(ShoppingCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
            } footer: {
                Text("Changes apply to all recipes and to this week's and future shopping lists. Past weeks won't change.")
            }

            Section("Used In") {
                if mealsUsingIngredient.isEmpty {
                    Text("Not used in any meals")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(mealsUsingIngredient) { meal in
                        Text(meal.name)
                    }
                }
            }

            Section {
                Button("Merge Into Another Ingredient…") { showingMergePicker = true }

                Button("Delete Ingredient", role: .destructive) { showingDeleteConfirmation = true }
                    .disabled(!mealsUsingIngredient.isEmpty)
            } footer: {
                if !mealsUsingIngredient.isEmpty {
                    Text("Used in \(mealsUsingIngredient.count) meal\(mealsUsingIngredient.count == 1 ? "" : "s"). Remove it from those meals or merge it into another ingredient first.")
                }
            }
        }
        .navigationTitle(ingredient.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(NameNormalizer.clean(name).isEmpty)
            }
        }
        .sheet(isPresented: $showingMergePicker) {
            IngredientPickerSheet(excludedIngredientID: ingredient.id, showsCreateRow: false) { target in
                mergeTarget = target
            }
        }
        .confirmationDialog(
            "Merge Ingredients?",
            isPresented: Binding(get: { mergeTarget != nil }, set: { if !$0 { mergeTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Merge", role: .destructive) { performMerge() }
            Button("Cancel", role: .cancel) { mergeTarget = nil }
        } message: {
            Text(mergeDialogMessage)
        }
        .confirmationDialog(
            "Delete Ingredient?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete \"\(ingredient.name)\"? This can't be undone.")
        }
        .alert(
            duplicateAlertTitle,
            isPresented: Binding(get: { duplicateName != nil }, set: { if !$0 { duplicateName = nil } })
        ) {
            Button("Merge Into \"\(duplicateName ?? "")\"") { mergeIntoDuplicate() }
            Button("OK", role: .cancel) { duplicateName = nil }
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var mergeDialogMessage: String {
        guard let mergeTarget else { return "" }
        return "Merge \"\(ingredient.name)\" into \"\(mergeTarget.name)\"? Every recipe will use \"\(mergeTarget.name)\". This can't be undone."
    }

    private var duplicateAlertTitle: String {
        guard let duplicateName else { return "" }
        return "An ingredient called \"\(duplicateName)\" already exists."
    }

    private func save() {
        do {
            try IngredientStore(context: modelContext).update(ingredient, name: name, defaultUnit: defaultUnit, category: category)
            dismiss()
        } catch AppError.duplicateIngredientName(let existingName) {
            duplicateName = existingName
        } catch {
            logger.error("Failed to update ingredient: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func mergeIntoDuplicate() {
        guard let duplicateName else { return }
        do {
            let store = IngredientStore(context: modelContext)
            guard let target = try store.find(named: duplicateName) else { return }
            try store.merge(ingredient, into: target)
            dismiss()
        } catch {
            logger.error("Failed to merge into existing ingredient: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
        self.duplicateName = nil
    }

    private func performMerge() {
        guard let mergeTarget else { return }
        do {
            try IngredientStore(context: modelContext).merge(ingredient, into: mergeTarget)
            dismiss()
        } catch {
            logger.error("Failed to merge ingredient: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
        self.mergeTarget = nil
    }

    private func performDelete() {
        do {
            try IngredientStore(context: modelContext).delete(ingredient)
            dismiss()
        } catch {
            logger.error("Failed to delete ingredient: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }
}

#Preview {
    NavigationStack {
        IngredientDetailView(ingredient: Ingredient(name: "Onion", defaultUnit: .item, category: .produce))
    }
    .modelContainer(PreviewContainer.shared)
}
