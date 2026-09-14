import Testing
@testable import MealPlanner

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
}
