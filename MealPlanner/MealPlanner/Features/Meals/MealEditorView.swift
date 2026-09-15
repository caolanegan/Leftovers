import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "MealEditor")

private let timeOptions = [5, 10, 15, 20, 25, 30, 40, 45, 60, 75, 90, 120, 150, 180]

/// A sheet with its own `NavigationStack`, used for both create (`meal ==
/// nil`) and edit. Edits a `MealDraft` value, never the model (§10.6).
struct MealEditorView: View {
    var meal: Meal? = nil
    /// Preselects a single meal type when creating (§10.2's picker "+ New
    /// Meal"). Ignored when editing an existing meal.
    var presetMealType: MealType? = nil
    /// Called with the created/updated meal right before the sheet dismisses,
    /// so a caller (e.g. `MealPickerSheet`) can assign it to a plan slot.
    var onSave: ((Meal) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MealDraft
    @State private var originalDraft: MealDraft
    @State private var showingDiscardConfirmation = false
    @State private var showingAddIngredient = false
    @State private var editingLine: RecipeLineDraft?
    @State private var errorMessage: String?
    @FocusState private var nameFieldFocused: Bool

    init(meal: Meal? = nil, presetMealType: MealType? = nil, onSave: ((Meal) -> Void)? = nil) {
        self.meal = meal
        self.presetMealType = presetMealType
        self.onSave = onSave
        var initial = meal.map(MealDraft.init(meal:)) ?? MealDraft()
        if meal == nil, let presetMealType { initial.mealTypes = [presetMealType] }
        _draft = State(initialValue: initial)
        _originalDraft = State(initialValue: initial)
    }

    private var hasChanges: Bool { draft != originalDraft }

    var body: some View {
        NavigationStack {
            Form {
                MealEditorPhotoSection(photo: $draft.photo, thumbnail: $draft.thumbnail, mealName: draft.name)
                detailsSection
                suitableForSection
                ingredientsSection
                methodSection
                notesSection
            }
            .navigationTitle(meal == nil ? "New Meal" : "Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancelTapped() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!draft.isValid)
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .confirmationDialog(
                "Discard Changes?",
                isPresented: $showingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
            .sheet(isPresented: $showingAddIngredient) {
                IngredientPickerSheet(
                    recipeCompletion: .init(
                        onAdd: { line in draft.lines.append(line) },
                        onFinish: { showingAddIngredient = false }
                    )
                )
            }
            .sheet(item: $editingLine) { line in
                NavigationStack {
                    if let ingredient = ingredient(for: line.ingredientID) {
                        RecipeIngredientForm(
                            ingredient: ingredient,
                            mode: .edit(existing: line, onSave: { updated in
                                if let index = draft.lines.firstIndex(where: { $0.id == updated.id }) {
                                    draft.lines[index] = updated
                                }
                            })
                        )
                    }
                }
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                if meal == nil { nameFieldFocused = true }
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Name", text: $draft.name)
                .focused($nameFieldFocused)
            Stepper("Serves \(draft.servings)", value: $draft.servings, in: 1...12)
            Picker("Time", selection: $draft.totalMinutes) {
                Text("Not set").tag(Int?.none)
                ForEach(timeOptions, id: \.self) { minutes in
                    Text(DurationFormatter.format(minutes: minutes)).tag(Int?.some(minutes))
                }
            }
        }
    }

    private var suitableForSection: some View {
        Section {
            ForEach(MealType.allCases) { type in
                Toggle(type.displayName, isOn: mealTypeBinding(type))
            }
            Toggle("Good as Leftovers", systemImage: "arrow.uturn.backward", isOn: $draft.goodAsLeftovers)
        } header: {
            Text("Suitable For")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if draft.mealTypes.isEmpty {
                    Text("Choose at least one.")
                        .foregroundStyle(.red)
                }
                Text("When on, planning this meal again within 3 days asks if it's leftovers.")
            }
        }
    }

    private var ingredientsSection: some View {
        Section("Ingredients") {
            ForEach(draft.lines) { line in
                Button {
                    editingLine = line
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.ingredientName)
                                .foregroundStyle(.primary)
                            if !line.note.isEmpty {
                                Text(line.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let amount = amountText(line) {
                            Text(amount)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete { draft.lines.remove(atOffsets: $0) }
            .onMove { draft.lines.move(fromOffsets: $0, toOffset: $1) }

            Button {
                showingAddIngredient = true
            } label: {
                Label("Add Ingredient", systemImage: "plus")
            }
        }
    }

    private var methodSection: some View {
        Section("Method") {
            ForEach(Array(draft.steps.enumerated()), id: \.element.id) { index, _ in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    TextField("Step", text: $draft.steps[index].text, axis: .vertical)
                }
            }
            .onDelete { draft.steps.remove(atOffsets: $0) }
            .onMove { draft.steps.move(fromOffsets: $0, toOffset: $1) }

            Button {
                draft.steps.append(StepDraft(id: UUID(), text: ""))
            } label: {
                Label("Add Step", systemImage: "plus")
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Notes", text: $draft.notes, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    private func mealTypeBinding(_ type: MealType) -> Binding<Bool> {
        Binding(
            get: { draft.mealTypes.contains(type) },
            set: { isOn in
                if isOn { draft.mealTypes.insert(type) } else { draft.mealTypes.remove(type) }
            }
        )
    }

    private func amountText(_ line: RecipeLineDraft) -> String? {
        guard let quantity = line.quantity else { return nil }
        return QuantityFormatter.format(quantity, unit: line.unit)
    }

    private func ingredient(for id: UUID) -> Ingredient? {
        var descriptor = FetchDescriptor<Ingredient>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func cancelTapped() {
        if hasChanges {
            showingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func save() {
        do {
            let savedMeal: Meal
            if let meal {
                try MealStore(context: modelContext).update(meal, from: draft)
                savedMeal = meal
            } else {
                savedMeal = try MealStore(context: modelContext).create(from: draft)
            }
            onSave?(savedMeal)
            dismiss()
        } catch {
            logger.error("Failed to save meal: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }
}

#Preview {
    MealEditorView()
        .modelContainer(PreviewContainer.shared)
}
