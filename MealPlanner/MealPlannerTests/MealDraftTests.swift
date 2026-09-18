import Foundation
import Testing
@testable import Leftovers

@MainActor
struct MealDraftTests {
    @Test func isValidRequiresACleanNameAndAtLeastOneMealType() {
        var draft = MealDraft()
        draft.name = "  "
        #expect(draft.isValid == false)

        draft.name = "Soup"
        #expect(draft.isValid == true)

        draft.mealTypes = []
        #expect(draft.isValid == false)
    }

    @Test func normalizedCleansTheName() {
        var draft = MealDraft()
        draft.name = "  Tomato   soup "
        #expect(draft.normalized().name == "Tomato soup")
    }

    @Test func normalizedTrimsNotes() {
        var draft = MealDraft()
        draft.notes = "  Night off from cooking.  "
        #expect(draft.normalized().notes == "Night off from cooking.")
    }

    @Test func normalizedTrimsStepTextAndDropsEmptySteps() {
        var draft = MealDraft()
        draft.steps = [
            StepDraft(id: UUID(), text: "  Brown the mince.  "),
            StepDraft(id: UUID(), text: "   "),
            StepDraft(id: UUID(), text: ""),
            StepDraft(id: UUID(), text: "Simmer for 25 minutes."),
        ]

        let steps = draft.normalized().steps
        #expect(steps.map(\.text) == ["Brown the mince.", "Simmer for 25 minutes."])
    }
}
