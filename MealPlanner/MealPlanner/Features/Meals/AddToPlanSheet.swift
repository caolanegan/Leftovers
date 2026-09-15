import SwiftUI
import SwiftData
import UIKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "AddToPlan")

/// §10.8. "Add" runs the full leftovers-aware assign flow (§10.3).
struct AddToPlanSheet: View {
    let meal: Meal

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var weekOffset = 0
    @State private var selectedDayIndex: Int
    @State private var selectedMealType: MealType
    @State private var errorMessage: String?
    @State private var pendingLeftoverPrompt: LeftoverOrCookAgainPrompt?
    @State private var pendingDependentPrompt: DependentLeftoversPrompt?

    init(meal: Meal) {
        self.meal = meal
        _selectedMealType = State(initialValue: meal.mealTypes.sorted().first ?? .dinner)
        _selectedDayIndex = State(initialValue: WeekMath.dayIndex(for: .now, calendar: WeekMath.appCalendar))
    }

    private var availableMealTypes: [MealType] { meal.mealTypes.sorted() }

    private var weekID: String {
        let current = WeekMath.weekID(for: .now, calendar: WeekMath.appCalendar)
        return weekOffset == 0 ? current : WeekMath.weekID(current, adding: 1, calendar: WeekMath.appCalendar)
    }

    private var existingSlotMeals: [Int: Meal] {
        guard let plan = try? WeekPlanService(context: modelContext).plan(for: weekID) else { return [:] }
        var result: [Int: Meal] = [:]
        for slot in plan.slots ?? [] where slot.mealType == selectedMealType {
            if let existingMeal = slot.meal { result[slot.dayIndex] = existingMeal }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Week", selection: $weekOffset) {
                        Text("This Week").tag(0)
                        Text("Next Week").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                if availableMealTypes.count > 1 {
                    Section {
                        Picker("Meal", selection: $selectedMealType) {
                            ForEach(availableMealTypes) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Section {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        dayRow(dayIndex)
                    }
                }
            }
            .navigationTitle("Add to Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
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
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func dayRow(_ dayIndex: Int) -> some View {
        Button {
            selectedDayIndex = dayIndex
        } label: {
            HStack {
                Text(dayLabel(dayIndex))
                    .foregroundStyle(.primary)
                Spacer()
                if let existingMeal = existingSlotMeals[dayIndex] {
                    Text(existingMeal.id == meal.id ? "Already planned" : "Replaces \(existingMeal.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if selectedDayIndex == dayIndex {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayLabel(_ dayIndex: Int) -> String {
        guard let date = WeekMath.date(dayIndex: dayIndex, in: weekID, calendar: WeekMath.appCalendar) else {
            return WeekMath.shortDayName(dayIndex)
        }
        let formatter = DateFormatter()
        formatter.calendar = WeekMath.appCalendar
        formatter.timeZone = WeekMath.appCalendar.timeZone
        formatter.locale = .current
        formatter.dateFormat = "d MMM"
        return "\(WeekMath.shortDayName(dayIndex)) \(formatter.string(from: date))"
    }

    private var position: PlanPosition {
        PlanPosition(weekID: weekID, dayIndex: selectedDayIndex, mealType: selectedMealType)
    }

    /// Runs the full leftovers-aware assign flow (§10.3): a leftovers prompt
    /// if there are source candidates, then a dependent-leftovers dialog if
    /// replacing a cooked meal that has leftovers depending on it.
    private func add() {
        do {
            switch try WeekPlanService(context: modelContext).assignmentDecision(forAssigning: meal, at: position) {
            case .needsLeftoverPrompt(let candidates):
                presentLeftoverPrompt(candidates)
            case .needsDependentPrompt(let dependents):
                presentDependentPrompt(dependents)
            case .readyToAssign:
                finishAssign(leftoversOf: nil)
            }
        } catch {
            logger.error("Failed to check leftovers: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func presentLeftoverPrompt(_ candidates: [PlanOccurrence]) {
        guard let nearest = candidates.first else {
            finishAssign(leftoversOf: nil)
            return
        }
        pendingLeftoverPrompt = LeftoverOrCookAgainPrompt(
            mealName: meal.name,
            nearestLabel: LeftoverRules.label(for: nearest.position),
            nearestButtonLabel: "\(WeekMath.shortDayName(nearest.position.dayIndex)) \(nearest.position.mealType.displayName)",
            onChooseLeftovers: { finishAssign(leftoversOf: nearest.slotID) },
            onChooseCookAgain: { proceedCooked() }
        )
    }

    /// After "Cook Again" (or when there were no candidates to begin with):
    /// still needs the dependent-leftovers check before assigning as cooked.
    private func proceedCooked() {
        do {
            switch try WeekPlanService(context: modelContext).dependentDecision(forCookedAssignmentOf: meal, at: position) {
            case .needsDependentPrompt(let dependents):
                presentDependentPrompt(dependents)
            default:
                finishAssign(leftoversOf: nil)
            }
        } catch {
            logger.error("Failed to check dependents: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func presentDependentPrompt(_ dependents: [MealSlot]) {
        pendingDependentPrompt = .make(for: position, dependents: dependents) { action in
            finishAssign(leftoversOf: nil, dependents: action)
        }
    }

    private func finishAssign(leftoversOf sourceSlotID: UUID?, dependents: DependentLeftoversAction = .keepAsCooked) {
        do {
            try WeekPlanService(context: modelContext).assign(meal, at: position, leftoversOf: sourceSlotID, dependents: dependents)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            logger.error("Failed to add to plan: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }
}

#Preview {
    AddToPlanSheet(meal: Meal(name: "Chicken fajitas"))
        .modelContainer(PreviewContainer.shared)
}
