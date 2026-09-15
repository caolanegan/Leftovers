import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "MealPicker")

/// §10.2. The Shuffle button (M8) and the leftovers prompt (§10.3, M7) aren't
/// built yet — tapping a meal always assigns it as cooked.
struct MealPickerSheet: View {
    let weekID: String
    let dayIndex: Int
    let mealType: MealType
    let currentMeal: Meal?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var meals: [Meal]
    @State private var searchText = ""
    @State private var showAllMeals = false
    @State private var showingNewMeal = false
    @State private var errorMessage: String?
    @State private var previousWeekMealIDs: Set<UUID> = []

    private var position: PlanPosition { PlanPosition(weekID: weekID, dayIndex: dayIndex, mealType: mealType) }

    private var filtered: [Meal] {
        var result = showAllMeals ? meals : meals.filter { $0.suits(mealType) }
        let key = NameNormalizer.key(searchText)
        if !key.isEmpty {
            result = result.filter { NameNormalizer.key($0.name).contains(key) }
        }
        return result.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Show All Meals", isOn: $showAllMeals)
                }

                Section {
                    ForEach(filtered) { meal in
                        row(for: meal)
                    }
                }

                if currentMeal != nil {
                    Section {
                        Button("Remove from Plan", role: .destructive) { remove() }
                    }
                }
            }
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView {
                        Label("No \(mealType.displayName) Meals", systemImage: mealType.symbolName)
                    } description: {
                        Text("Add a meal suited to \(mealType.displayName.lowercased()).")
                    } actions: {
                        Button("New Meal") { showingNewMeal = true }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search meals")
            .navigationTitle("\(WeekMath.shortDayName(dayIndex).fullDayName) \(mealType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewMeal = true
                    } label: {
                        Label("New Meal", systemImage: "plus")
                    }
                    .accessibilityLabel("New Meal")
                }
            }
            .sheet(isPresented: $showingNewMeal) {
                MealEditorView(presetMealType: mealType) { meal in
                    assign(meal)
                }
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task {
            let previousWeekID = WeekMath.weekID(weekID, adding: -1, calendar: WeekMath.appCalendar)
            previousWeekMealIDs = (try? WeekPlanService(context: modelContext).mealIDs(inWeek: previousWeekID)) ?? []
        }
    }

    private func row(for meal: Meal) -> some View {
        Button {
            assign(meal)
        } label: {
            HStack {
                MealThumbnail(thumbnailData: meal.thumbnailData, mealName: meal.name, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.name)
                        .foregroundStyle(.primary)
                    if previousWeekMealIDs.contains(meal.id) {
                        Text("Had last week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if currentMeal?.id == meal.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func assign(_ meal: Meal) {
        do {
            try WeekPlanService(context: modelContext).assign(meal, at: position)
            dismiss()
        } catch {
            logger.error("Failed to assign meal: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func remove() {
        do {
            try WeekPlanService(context: modelContext).clearSlot(at: position, dependents: .remove)
            dismiss()
        } catch {
            logger.error("Failed to remove from plan: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }
}

private extension String {
    /// Expands a `WeekMath.shortDayName` result ("Tue") to its full form
    /// ("Tuesday") for the sheet's navigation title (§10.2: "Tuesday Dinner").
    var fullDayName: String {
        let names = [
            "Mon": "Monday", "Tue": "Tuesday", "Wed": "Wednesday", "Thu": "Thursday",
            "Fri": "Friday", "Sat": "Saturday", "Sun": "Sunday",
        ]
        return names[self] ?? self
    }
}

#Preview {
    MealPickerSheet(
        weekID: WeekMath.weekID(for: .now, calendar: WeekMath.appCalendar),
        dayIndex: 0,
        mealType: .dinner,
        currentMeal: nil
    )
    .modelContainer(PreviewContainer.shared)
}
