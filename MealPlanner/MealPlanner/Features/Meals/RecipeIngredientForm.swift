import SwiftUI

/// Step 2 of §10.7's "add ingredient to a recipe" flow, also used standalone
/// for editing an existing recipe line (§10.6 item 4). In add mode it's
/// pushed inside `IngredientPickerSheet`'s `NavigationStack`; in edit mode
/// it's presented directly, wrapped in its own `NavigationStack`.
struct RecipeIngredientForm: View {
    let ingredient: Ingredient
    var existingLine: RecipeLineDraft? = nil
    var onAdd: ((RecipeLineDraft) -> Void)? = nil
    var onAddAndNext: ((RecipeLineDraft) -> Void)? = nil
    var onSave: ((RecipeLineDraft) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var unit: IngredientUnit
    @State private var note: String

    private var isEditMode: Bool { existingLine != nil }

    init(
        ingredient: Ingredient,
        existingLine: RecipeLineDraft? = nil,
        onAdd: ((RecipeLineDraft) -> Void)? = nil,
        onAddAndNext: ((RecipeLineDraft) -> Void)? = nil,
        onSave: ((RecipeLineDraft) -> Void)? = nil
    ) {
        self.ingredient = ingredient
        self.existingLine = existingLine
        self.onAdd = onAdd
        self.onAddAndNext = onAddAndNext
        self.onSave = onSave
        _amountText = State(initialValue: existingLine?.quantity.map(QuantityFormatter.number) ?? "")
        _unit = State(initialValue: existingLine?.unit ?? ingredient.defaultUnit)
        _note = State(initialValue: existingLine?.note ?? "")
    }

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
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ingredient.name)
                        Text(ingredient.category.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !isEditMode {
                        Button("Change") { dismiss() }
                    }
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
            Section {
                TextField("Note", text: $note, prompt: Text("e.g. finely chopped"))
            }
        }
        .navigationTitle(ingredient.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditMode {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave?(makeLine())
                        dismiss()
                    }
                    .disabled(isAmountInvalid)
                }
            } else {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Add") { onAdd?(makeLine()) }
                        .disabled(isAmountInvalid)
                    Button("Add & Next") { onAddAndNext?(makeLine()) }
                        .disabled(isAmountInvalid)
                }
            }
        }
    }

    private func makeLine() -> RecipeLineDraft {
        RecipeLineDraft(
            id: existingLine?.id ?? UUID(),
            ingredientID: ingredient.id,
            ingredientName: ingredient.name,
            quantity: quantity,
            unit: unit,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

#Preview {
    NavigationStack {
        RecipeIngredientForm(ingredient: Ingredient(name: "Onion", defaultUnit: .item, category: .produce))
    }
}
