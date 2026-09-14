import SwiftUI

/// Step 2 of §10.7's "add ingredient to a recipe" flow, also used standalone
/// for editing an existing recipe line (§10.6 item 4). In add mode it's
/// pushed inside `IngredientPickerSheet`'s `NavigationStack`; in edit mode
/// it's presented directly, wrapped in its own `NavigationStack`.
///
/// `mode` carries each case's required callbacks itself (rather than a set
/// of optional closure parameters) so a caller can't accidentally leave one
/// unset — that's what let a trailing closure meant for `onSave` silently
/// bind to a different, unused parameter instead.
struct RecipeIngredientForm: View {
    enum Mode {
        case add(onAdd: (RecipeLineDraft) -> Void, onAddAndNext: (RecipeLineDraft) -> Void)
        case edit(existing: RecipeLineDraft, onSave: (RecipeLineDraft) -> Void)
    }

    let ingredient: Ingredient
    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var unit: IngredientUnit
    @State private var note: String

    private var existingLine: RecipeLineDraft? {
        if case .edit(let existing, _) = mode { return existing }
        return nil
    }

    init(ingredient: Ingredient, mode: Mode) {
        self.ingredient = ingredient
        self.mode = mode
        let existing: RecipeLineDraft? = {
            if case .edit(let existing, _) = mode { return existing }
            return nil
        }()
        _amountText = State(initialValue: existing?.quantity.map(QuantityFormatter.number) ?? "")
        _unit = State(initialValue: existing?.unit ?? ingredient.defaultUnit)
        _note = State(initialValue: existing?.note ?? "")
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
                    if case .add = mode {
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
            if case .edit(_, let onSave) = mode {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(makeLine())
                        dismiss()
                    }
                    .disabled(isAmountInvalid)
                }
            } else if case .add(let onAdd, let onAddAndNext) = mode {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Add") { onAdd(makeLine()) }
                        .disabled(isAmountInvalid)
                    Button("Add & Next") { onAddAndNext(makeLine()) }
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
        RecipeIngredientForm(
            ingredient: Ingredient(name: "Onion", defaultUnit: .item, category: .produce),
            mode: .add(onAdd: { _ in }, onAddAndNext: { _ in })
        )
    }
}
