import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "NewIngredientForm")

/// A form that creates a single `Ingredient`. Presented either as its own sheet
/// (from the library's "+" toolbar) or pushed inside `IngredientPickerSheet`'s
/// search results (the picker's "Create" row).
struct NewIngredientForm: View {
    var prefilledName: String = ""
    var showsCancelButton: Bool = true
    var onCreate: (Ingredient) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var defaultUnit: IngredientUnit = .item
    @State private var category: ShoppingCategory = .other
    @State private var errorMessage: String?

    init(prefilledName: String = "", showsCancelButton: Bool = true, onCreate: @escaping (Ingredient) -> Void) {
        self.prefilledName = prefilledName
        self.showsCancelButton = showsCancelButton
        self.onCreate = onCreate
        _name = State(initialValue: NameNormalizer.clean(prefilledName))
    }

    private var isNameValid: Bool { !NameNormalizer.clean(name).isEmpty }

    var body: some View {
        Form {
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
        }
        .navigationTitle("New Ingredient")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { create() }
                    .disabled(!isNameValid)
            }
            if showsCancelButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func create() {
        do {
            let ingredient = try IngredientStore(context: modelContext)
                .create(name: name, defaultUnit: defaultUnit, category: category)
            onCreate(ingredient)
        } catch {
            logger.error("Failed to create ingredient: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }
}

#Preview {
    NavigationStack {
        NewIngredientForm { _ in }
    }
    .modelContainer(PreviewContainer.shared)
}
