import Testing
import Foundation
@testable import MealPlanner

@MainActor
struct LeftoverRulesTests {
    let calendar = WeekMath.appCalendar
    let mealID = UUID()
    let otherMealID = UUID()

    private func occurrence(
        weekID: String, dayIndex: Int, mealType: MealType, mealID: UUID? = nil, isLeftovers: Bool = false
    ) -> PlanOccurrence {
        PlanOccurrence(
            slotID: UUID(),
            position: PlanPosition(weekID: weekID, dayIndex: dayIndex, mealType: mealType),
            mealID: mealID ?? self.mealID,
            isLeftovers: isLeftovers
        )
    }

    @Test func mondayDinnerIsACandidateForTuesdayLunch() {
        let source = occurrence(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        let target = PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch)

        let candidates = LeftoverRules.sourceCandidates(mealID: mealID, target: target, occurrences: [source], calendar: calendar)

        #expect(candidates.map(\.slotID) == [source.slotID])
    }

    @Test func mondayDinnerIsNotACandidateForFridayDinnerFourDaysLater() {
        let source = occurrence(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        let target = PlanPosition(weekID: "2026-W38", dayIndex: 4, mealType: .dinner)

        let candidates = LeftoverRules.sourceCandidates(mealID: mealID, target: target, occurrences: [source], calendar: calendar)

        #expect(candidates.isEmpty)
    }

    @Test func sundayDinnerIsACandidateForNextWeeksMondayLunch() {
        let source = occurrence(weekID: "2026-W38", dayIndex: 6, mealType: .dinner)
        let target = PlanPosition(weekID: "2026-W39", dayIndex: 0, mealType: .lunch)

        let candidates = LeftoverRules.sourceCandidates(mealID: mealID, target: target, occurrences: [source], calendar: calendar)

        #expect(candidates.map(\.slotID) == [source.slotID])
    }

    @Test func aLaterOccurrenceIsNotACandidate() {
        let source = occurrence(weekID: "2026-W38", dayIndex: 1, mealType: .lunch)
        let target = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)

        let candidates = LeftoverRules.sourceCandidates(mealID: mealID, target: target, occurrences: [source], calendar: calendar)

        #expect(candidates.isEmpty)
    }

    @Test func aLeftoversSlotIsNeverACandidate() {
        let source = occurrence(weekID: "2026-W38", dayIndex: 0, mealType: .dinner, isLeftovers: true)
        let target = PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch)

        let candidates = LeftoverRules.sourceCandidates(mealID: mealID, target: target, occurrences: [source], calendar: calendar)

        #expect(candidates.isEmpty)
    }

    @Test func sameDayDinnerIsNotACandidateForLunchBecauseDinnerIsLater() {
        let source = occurrence(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        let target = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .lunch)

        let candidates = LeftoverRules.sourceCandidates(mealID: mealID, target: target, occurrences: [source], calendar: calendar)

        #expect(candidates.isEmpty)
    }

    @Test func sameDayBreakfastIsACandidateForLunch() {
        let source = occurrence(weekID: "2026-W38", dayIndex: 0, mealType: .breakfast)
        let target = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .lunch)

        let candidates = LeftoverRules.sourceCandidates(mealID: mealID, target: target, occurrences: [source], calendar: calendar)

        #expect(candidates.map(\.slotID) == [source.slotID])
    }

    @Test func candidatesAreSortedNearestFirstThenLaterMealTypeFirst() {
        let farther = occurrence(weekID: "2026-W37", dayIndex: 6, mealType: .dinner)   // 2 days before target
        let nearerLunch = occurrence(weekID: "2026-W38", dayIndex: 0, mealType: .lunch) // 1 day before target
        let nearerDinner = occurrence(weekID: "2026-W38", dayIndex: 0, mealType: .dinner) // 1 day before target
        let target = PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch)

        let candidates = LeftoverRules.sourceCandidates(
            mealID: mealID, target: target,
            occurrences: [farther, nearerLunch, nearerDinner],
            calendar: calendar
        )

        #expect(candidates.map(\.slotID) == [nearerDinner.slotID, nearerLunch.slotID, farther.slotID])
    }

    @Test func candidatesExcludeOtherMealsAndAreEmptyWhenNoneMatch() {
        let other = occurrence(weekID: "2026-W38", dayIndex: 0, mealType: .dinner, mealID: otherMealID)
        let target = PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch)

        let candidates = LeftoverRules.sourceCandidates(mealID: mealID, target: target, occurrences: [other], calendar: calendar)

        #expect(candidates.isEmpty)
    }

    @Test func dependentPromptTitleUsesFullDayNameAndLowercaseMealType() {
        let position = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        #expect(LeftoverRules.dependentPromptTitle(for: position) == "Monday dinner has leftovers planned")
    }

    @Test func dependentPromptMessageForOneDependent() {
        let dependent = PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch)
        #expect(LeftoverRules.dependentPromptMessage(for: [dependent]) == "Tuesday lunch is leftovers from this meal.")
    }

    @Test func dependentPromptMessageForMultipleDependents() {
        let first = PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch)
        let second = PlanPosition(weekID: "2026-W38", dayIndex: 2, mealType: .lunch)
        #expect(LeftoverRules.dependentPromptMessage(for: [first, second]) == "Tuesday lunch and Wednesday lunch are leftovers from this meal.")
    }
}
