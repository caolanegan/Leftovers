import SwiftUI

/// Both of §10.3's shared leftovers prompts, used by the Plan screen
/// (`WeekPlanView`) and the meal-assignment flows in `MealPickerSheet` and
/// `AddToPlanSheet`.

// MARK: - A. "Leftovers or cook again?"

struct LeftoverOrCookAgainPrompt: Identifiable {
    let id = UUID()
    let mealName: String
    let nearestLabel: String          // "Mon dinner", for the message
    let nearestButtonLabel: String    // "Mon Dinner", for the button
    let onChooseLeftovers: () -> Void
    let onChooseCookAgain: () -> Void
}

extension View {
    func leftoverOrCookAgainDialog(_ prompt: Binding<LeftoverOrCookAgainPrompt?>) -> some View {
        confirmationDialog(
            "Leftovers or cook again?",
            isPresented: Binding(get: { prompt.wrappedValue != nil }, set: { if !$0 { prompt.wrappedValue = nil } }),
            titleVisibility: .visible
        ) {
            if let value = prompt.wrappedValue {
                Button("Leftovers from \(value.nearestButtonLabel)", action: value.onChooseLeftovers)
                Button("Cook Again", action: value.onChooseCookAgain)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let value = prompt.wrappedValue {
                Text("\(value.mealName) is planned for \(value.nearestLabel). Leftovers won't add anything to your shopping list.")
            }
        }
    }
}

// MARK: - B. Dependent leftovers

struct DependentLeftoversPrompt: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let onChoice: (DependentLeftoversAction) -> Void

    /// Builds the dialog's copy from the slot being changed and the slots that depend on it.
    static func make(for position: PlanPosition, dependents: [MealSlot], onChoice: @escaping (DependentLeftoversAction) -> Void) -> DependentLeftoversPrompt {
        let dependentPositions = dependents.map {
            PlanPosition(weekID: $0.weekPlan?.weekID ?? position.weekID, dayIndex: $0.dayIndex, mealType: $0.mealType)
        }
        return DependentLeftoversPrompt(
            title: LeftoverRules.dependentPromptTitle(for: position),
            message: LeftoverRules.dependentPromptMessage(for: dependentPositions),
            onChoice: onChoice
        )
    }
}

extension View {
    func dependentLeftoversDialog(_ prompt: Binding<DependentLeftoversPrompt?>) -> some View {
        confirmationDialog(
            prompt.wrappedValue?.title ?? "",
            isPresented: Binding(get: { prompt.wrappedValue != nil }, set: { if !$0 { prompt.wrappedValue = nil } }),
            titleVisibility: .visible
        ) {
            if let value = prompt.wrappedValue {
                Button("Remove Leftovers Too", role: .destructive) { value.onChoice(.remove) }
                Button("Keep as Cooked Meal") { value.onChoice(.keepAsCooked) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let value = prompt.wrappedValue {
                Text(value.message)
            }
        }
    }
}
