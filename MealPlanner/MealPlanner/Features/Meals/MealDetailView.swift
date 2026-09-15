import SwiftUI
import SwiftData
import UIKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "MealDetail")

struct MealDetailView: View {
    let meal: Meal
    /// The enclosing tab's bound navigation path, if it has one. Used by
    /// `duplicate()` to replace this screen with the new meal (§10.5) so Back
    /// still returns to the library instead of the meal that was duplicated.
    var path: Binding<NavigationPath>? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditor = false
    @State private var showingAddToPlan = false
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let photoData = meal.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 240)
                    .clipped()
                    .accessibilityLabel("Photo of \(meal.name)")
                    .listRowInsets(EdgeInsets())
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(meal.mealTypes.sorted()) { type in
                            Text(type.displayName)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text(servesAndTimeCaption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Add to Plan") { showingAddToPlan = true }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
                .listRowSeparator(.hidden)
            }

            if !meal.sortedIngredients.isEmpty {
                Section("Ingredients") {
                    ForEach(meal.sortedIngredients) { line in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.ingredient?.name ?? "")
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
                    }
                }
            }

            if !meal.sortedSteps.isEmpty {
                Section("Method") {
                    ForEach(Array(meal.sortedSteps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .foregroundStyle(.secondary)
                                .frame(width: 20, alignment: .trailing)
                            Text(step.text)
                        }
                    }
                }
            }

            if !meal.notes.isEmpty {
                Section("Notes") {
                    Text(meal.notes)
                }
            }
        }
        .navigationTitle(meal.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: meal.isFavorite ? "star.fill" : "star")
                }
                .accessibilityLabel(meal.isFavorite ? "Remove from favourites" : "Add to favourites")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditor = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add to Plan") { showingAddToPlan = true }
                    Button("Duplicate") { duplicate() }
                    Button("Delete", role: .destructive) { showingDeleteConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $showingEditor) {
            MealEditorView(meal: meal)
        }
        .sheet(isPresented: $showingAddToPlan) {
            AddToPlanSheet(meal: meal)
        }
        .confirmationDialog(
            "Delete \"\(meal.name)\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var servesAndTimeCaption: String {
        var text = "Serves \(meal.servings)"
        if let minutes = meal.totalMinutes { text += " · \(minutes) min" }
        return text
    }

    private var deleteMessage: String {
        let count = MealStore(context: modelContext).upcomingPlanCount(for: meal)
        var sentences: [String] = []
        if count > 0 {
            sentences.append("It's planned \(count) time\(count == 1 ? "" : "s") in this and upcoming weeks and will be removed from those plans.")
        }
        sentences.append("Past weeks won't change.")
        sentences.append("This can't be undone.")
        return sentences.joined(separator: " ")
    }

    private func amountText(_ line: RecipeIngredient) -> String? {
        guard let quantity = line.quantity else { return nil }
        return QuantityFormatter.format(quantity, unit: line.unit)
    }

    private func toggleFavorite() {
        do {
            try MealStore(context: modelContext).toggleFavorite(meal)
        } catch {
            logger.error("Failed to toggle favourite: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func duplicate() {
        do {
            let copy = try MealStore(context: modelContext).duplicate(meal)
            if let path {
                path.wrappedValue.removeLast()
                path.wrappedValue.append(AppRoute.meal(copy))
            }
        } catch {
            logger.error("Failed to duplicate meal: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func performDelete() {
        do {
            try MealStore(context: modelContext).delete(meal)
            dismiss()
        } catch {
            logger.error("Failed to delete meal: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }
}

#Preview {
    NavigationStack {
        MealDetailView(meal: Meal(name: "Chicken fajitas"))
    }
    .modelContainer(PreviewContainer.shared)
}
