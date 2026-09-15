import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "AddShoppingItem")

/// §10.11, step 2 (the ingredient is already chosen — `ShoppingListView`
/// runs `IngredientPickerSheet` itself for step 1, same as the recipe-line
/// flow's `IngredientPickerSheet`/`RecipeIngredientForm` split). Opens
/// pre-filled in edit mode when this week already has a hand-added item for
/// the ingredient.
struct AddShoppingItemSheet: View {
    let weekID: String
    let ingredient: Ingredient
    let existingItem: ManualShoppingItem?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var unit: IngredientUnit
    @State private var errorMessage: String?

    init(weekID: String, ingredient: Ingredient, existingItem: ManualShoppingItem?) {
        self.weekID = weekID
        self.ingredient = ingredient
        self.existingItem = existingItem
        _amountText = State(initialValue: existingItem?.quantity.map(QuantityFormatter.number) ?? "")
        _unit = State(initialValue: existingItem?.unit ?? ingredient.defaultUnit)
    }

    private var isEditing: Bool { existingItem != nil }
    private var parseResult: QuantityParser.Result { QuantityParser.parse(amountText) }

    private var isAmountInvalid: Bool {
        if case .invalid = parseResult { return true }
        return false
    }

    private var quantity: Double? {
        if case .value(let value) = parseResult { return value }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ingredient.name)
                        Text(ingredient.category.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.numbersAndPunctuation)
                    Picker("Unit", selection: $unit) {
                        ForEach(IngredientUnit.allCases) { unit in
                            Text(unit.pickerLabel).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                } footer: {
                    if isAmountInvalid {
                        Text("Enter a number like 2, 1.5 or 1/2")
                            .foregroundStyle(.red)
                    }
                }
                if isEditing {
                    Section {
                        Button("Remove Added Item", role: .destructive) { remove() }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Added Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(isAmountInvalid)
                }
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        do {
            try WeekPlanService(context: modelContext).upsertManualItem(ingredient: ingredient, quantity: quantity, unit: unit, weekID: weekID)
            dismiss()
        } catch {
            logger.error("Failed to save hand-added item: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func remove() {
        do {
            try WeekPlanService(context: modelContext).removeManualItem(ingredientID: ingredient.id, weekID: weekID)
            dismiss()
        } catch {
            logger.error("Failed to remove hand-added item: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }
}

#Preview {
    AddShoppingItemSheet(
        weekID: WeekMath.weekID(for: .now, calendar: WeekMath.appCalendar),
        ingredient: Ingredient(name: "Toilet roll", defaultUnit: .pack, category: .household),
        existingItem: nil
    )
    .modelContainer(PreviewContainer.shared)
}
