import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "MealPicker")

/// §10.2. The Shuffle button (row re-roll and the picker's own Shuffle
/// button) is M8 — tapping a meal runs the full leftovers-aware assign flow.
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
    @State private var pendingLeftoverPrompt: LeftoverOrCookAgainPrompt?
    @State private var pendingDependentPrompt: DependentLeftoversPrompt?

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
            .navigationTitle("\(WeekMath.fullDayName(dayIndex)) \(mealType.displayName)")
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
                    startAssign(meal, at: position)
                }
            }
            .leftoverOrCookAgainDialog($pendingLeftoverPrompt)
            .dependentLeftoversDialog($pendingDependentPrompt)
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
            startAssign(meal, at: position)
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

    /// Runs the full leftovers-aware assign flow (§10.2, §10.3): a leftovers
    /// prompt if there are source candidates, then a dependent-leftovers
    /// dialog if replacing a cooked meal that has leftovers depending on it.
    private func startAssign(_ meal: Meal, at position: PlanPosition) {
        do {
            switch try WeekPlanService(context: modelContext).assignmentDecision(forAssigning: meal, at: position) {
            case .needsLeftoverPrompt(let candidates):
                presentLeftoverPrompt(candidates, meal: meal, position: position)
            case .needsDependentPrompt(let dependents):
                presentDependentPrompt(dependents, meal: meal, position: position)
            case .readyToAssign:
                finishAssign(meal, at: position, leftoversOf: nil)
            }
        } catch {
            logger.error("Failed to check leftovers: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func presentLeftoverPrompt(_ candidates: [PlanOccurrence], meal: Meal, position: PlanPosition) {
        guard let nearest = candidates.first else {
            finishAssign(meal, at: position, leftoversOf: nil)
            return
        }
        pendingLeftoverPrompt = LeftoverOrCookAgainPrompt(
            mealName: meal.name,
            nearestLabel: LeftoverRules.label(for: nearest.position),
            nearestButtonLabel: "\(WeekMath.shortDayName(nearest.position.dayIndex)) \(nearest.position.mealType.displayName)",
            onChooseLeftovers: { finishAssign(meal, at: position, leftoversOf: nearest.slotID) },
            onChooseCookAgain: { proceedCooked(meal, at: position) }
        )
    }

    /// After "Cook Again" (or when there were no candidates to begin with):
    /// still needs the dependent-leftovers check before assigning as cooked.
    private func proceedCooked(_ meal: Meal, at position: PlanPosition) {
        do {
            switch try WeekPlanService(context: modelContext).dependentDecision(forCookedAssignmentOf: meal, at: position) {
            case .needsDependentPrompt(let dependents):
                presentDependentPrompt(dependents, meal: meal, position: position)
            default:
                finishAssign(meal, at: position, leftoversOf: nil)
            }
        } catch {
            logger.error("Failed to check dependents: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func presentDependentPrompt(_ dependents: [MealSlot], meal: Meal, position: PlanPosition) {
        pendingDependentPrompt = .make(for: position, dependents: dependents) { action in
            finishAssign(meal, at: position, leftoversOf: nil, dependents: action)
        }
    }

    private func finishAssign(_ meal: Meal, at position: PlanPosition, leftoversOf sourceSlotID: UUID?, dependents: DependentLeftoversAction = .keepAsCooked) {
        do {
            try WeekPlanService(context: modelContext).assign(meal, at: position, leftoversOf: sourceSlotID, dependents: dependents)
            dismiss()
        } catch {
            logger.error("Failed to assign meal: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func remove() {
        do {
            let service = WeekPlanService(context: modelContext)
            let dependents = try service.dependentLeftovers(of: position)
            guard !dependents.isEmpty else {
                try service.clearSlot(at: position, dependents: .remove)
                dismiss()
                return
            }
            pendingDependentPrompt = .make(for: position, dependents: dependents) { action in
                do {
                    try WeekPlanService(context: modelContext).clearSlot(at: position, dependents: action)
                    dismiss()
                } catch {
                    logger.error("Failed to remove from plan: \(error, privacy: .public)")
                    errorMessage = "Something went wrong. Please try again."
                }
            }
        } catch {
            logger.error("Failed to remove from plan: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
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
