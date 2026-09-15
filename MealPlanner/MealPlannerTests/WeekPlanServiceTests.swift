import Foundation
import Testing
import SwiftData
@testable import MealPlanner

@MainActor
struct WeekPlanServiceTests {
    let container: ModelContainer
    let context: ModelContext
    let mealStore: MealStore
    let service: WeekPlanService
    let calendar = WeekMath.appCalendar
    let now: Date

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        context = container.mainContext
        mealStore = MealStore(context: context)

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        now = try #require(formatter.date(from: "2026-09-14 09:00"))
        service = WeekPlanService(context: context, now: now, calendar: calendar)
    }

    private func makeMeal(_ name: String) throws -> Meal {
        var draft = MealDraft()
        draft.name = name
        draft.mealTypes = [.breakfast, .lunch, .dinner]
        return try mealStore.create(from: draft)
    }

    /// Plants a slot directly (bypassing services, which refuse to touch an
    /// already-ended week) so a past week can be used as a copy source.
    @discardableResult
    private func plantSlot(weekID: String, dayIndex: Int, mealType: MealType, meal: Meal, leftoverOfSlotID: UUID? = nil) throws -> MealSlot {
        let plan = try fetchOrInsertPlan(weekID: weekID)
        let slot = MealSlot(dayIndex: dayIndex, mealType: mealType)
        slot.weekPlan = plan
        slot.meal = meal
        slot.leftoverOfSlotID = leftoverOfSlotID
        context.insert(slot)
        try context.save()
        return slot
    }

    private func fetchOrInsertPlan(weekID: String) throws -> WeekPlan {
        if let existing = try service.plan(for: weekID) { return existing }
        let plan = WeekPlan(weekID: weekID)
        context.insert(plan)
        try context.save()
        return plan
    }

    // MARK: - Reading

    @Test func browsingAWeekWithNoPlanDoesNotCreateOne() throws {
        #expect(try service.plan(for: "2026-W38") == nil)
        #expect(try context.fetch(FetchDescriptor<WeekPlan>()).isEmpty)
    }

    // MARK: - assign / clearSlot

    @Test func assignCreatesAPlanAndSlotOnFirstUse() throws {
        let meal = try makeMeal("Chicken fajitas")
        let position = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)

        try service.assign(meal, at: position)

        let plan = try #require(try service.plan(for: "2026-W38"))
        let slot = try #require((plan.slots ?? []).first)
        #expect(slot.meal?.id == meal.id)
        #expect(slot.dayIndex == 0)
        #expect(slot.mealType == .dinner)
    }

    @Test func assignReplacesAnOccupiedSlotsMeal() throws {
        let first = try makeMeal("Chicken fajitas")
        let second = try makeMeal("Veggie chilli")
        let position = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)

        try service.assign(first, at: position)
        try service.assign(second, at: position)

        let plan = try #require(try service.plan(for: "2026-W38"))
        #expect((plan.slots ?? []).count == 1)
        #expect((plan.slots ?? []).first?.meal?.id == second.id)
    }

    @Test func clearSlotRemovesTheSlot() throws {
        let meal = try makeMeal("Chicken fajitas")
        let position = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: position)

        try service.clearSlot(at: position, dependents: .remove)

        let plan = try #require(try service.plan(for: "2026-W38"))
        #expect((plan.slots ?? []).isEmpty)
    }

    @Test func clearSlotWithRemoveDeletesDependentLeftovers() throws {
        let meal = try makeMeal("Chicken fajitas")
        let cookedPosition = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: cookedPosition)
        let plan = try #require(try service.plan(for: "2026-W38"))
        let cookedSlot = try #require((plan.slots ?? []).first)

        let leftoverSlot = MealSlot(dayIndex: 1, mealType: .lunch)
        leftoverSlot.weekPlan = plan
        leftoverSlot.meal = meal
        leftoverSlot.leftoverOfSlotID = cookedSlot.id
        context.insert(leftoverSlot)
        try context.save()

        try service.clearSlot(at: cookedPosition, dependents: .remove)

        #expect((plan.slots ?? []).isEmpty)
    }

    @Test func clearSlotWithKeepAsCookedDetachesDependents() throws {
        let meal = try makeMeal("Chicken fajitas")
        let cookedPosition = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: cookedPosition)
        let plan = try #require(try service.plan(for: "2026-W38"))
        let cookedSlot = try #require((plan.slots ?? []).first)

        let leftoverSlot = MealSlot(dayIndex: 1, mealType: .lunch)
        leftoverSlot.weekPlan = plan
        leftoverSlot.meal = meal
        leftoverSlot.leftoverOfSlotID = cookedSlot.id
        context.insert(leftoverSlot)
        try context.save()

        try service.clearSlot(at: cookedPosition, dependents: .keepAsCooked)

        #expect((plan.slots ?? []).count == 1)
        #expect((plan.slots ?? []).first?.leftoverOfSlotID == nil)
    }

    @Test func clearWeekRemovesEverySlotAndResetsSharedSignature() throws {
        let meal = try makeMeal("Chicken fajitas")
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner))
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch))
        let plan = try #require(try service.plan(for: "2026-W38"))
        plan.lastSharedSignature = "abc"
        try context.save()

        try service.clearWeek("2026-W38")

        #expect((plan.slots ?? []).isEmpty)
        #expect(plan.lastSharedSignature == nil)
    }

    @Test func clearWeekRemovesDependentLeftoversInOtherWeeks() throws {
        let meal = try makeMeal("Chicken fajitas")
        let cookedPosition = PlanPosition(weekID: "2026-W38", dayIndex: 6, mealType: .dinner)
        try service.assign(meal, at: cookedPosition)
        let plan38 = try #require(try service.plan(for: "2026-W38"))
        let cookedSlot = try #require((plan38.slots ?? []).first)

        // Sunday dinner (W38) leftovers on Monday lunch (W39), across the week boundary.
        try service.assign(meal, at: PlanPosition(weekID: "2026-W39", dayIndex: 0, mealType: .lunch), leftoversOf: cookedSlot.id)

        try service.clearWeek("2026-W38")

        let nextWeekPlan = try #require(try service.plan(for: "2026-W39"))
        #expect((nextWeekPlan.slots ?? []).isEmpty)
    }

    @Test func weekHasDependentLeftoversDetectsCrossWeekDependents() throws {
        let meal = try makeMeal("Chicken fajitas")
        let cookedPosition = PlanPosition(weekID: "2026-W38", dayIndex: 6, mealType: .dinner)
        try service.assign(meal, at: cookedPosition)
        let plan38 = try #require(try service.plan(for: "2026-W38"))
        let cookedSlot = try #require((plan38.slots ?? []).first)

        #expect(try service.weekHasDependentLeftovers("2026-W38") == false)

        try service.assign(meal, at: PlanPosition(weekID: "2026-W39", dayIndex: 0, mealType: .lunch), leftoversOf: cookedSlot.id)

        #expect(try service.weekHasDependentLeftovers("2026-W38") == true)
    }

    // MARK: - copyWeek

    @Test func copyWeekFillEmptyOnlyFillsEmptySlots() throws {
        let mealX = try makeMeal("Chicken fajitas")
        let mealZ = try makeMeal("Veggie chilli")
        try plantSlot(weekID: "2026-W36", dayIndex: 0, mealType: .dinner, meal: mealX)
        try service.assign(mealZ, at: PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner))

        let result = try service.copyWeek(from: "2026-W36", to: "2026-W38", mode: .fillEmpty)

        #expect(result.copied == 0)
        let target = try #require(try service.plan(for: "2026-W38"))
        #expect((target.slots ?? []).first?.meal?.id == mealZ.id)
    }

    @Test func copyWeekReplaceAllOverwritesExistingSlots() throws {
        let mealX = try makeMeal("Chicken fajitas")
        let mealZ = try makeMeal("Veggie chilli")
        try plantSlot(weekID: "2026-W36", dayIndex: 0, mealType: .dinner, meal: mealX)
        try service.assign(mealZ, at: PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner))

        let result = try service.copyWeek(from: "2026-W36", to: "2026-W38", mode: .replaceAll)

        #expect(result.copied == 1)
        let target = try #require(try service.plan(for: "2026-W38"))
        #expect((target.slots ?? []).count == 1)
        #expect((target.slots ?? []).first?.meal?.id == mealX.id)
    }

    @Test func copyWeekRemapsLeftoverLinksWhenTheSourceSlotIsAlsoCopied() throws {
        let meal = try makeMeal("Chicken fajitas")
        let cookedSlot = try plantSlot(weekID: "2026-W36", dayIndex: 0, mealType: .dinner, meal: meal)
        try plantSlot(weekID: "2026-W36", dayIndex: 1, mealType: .lunch, meal: meal, leftoverOfSlotID: cookedSlot.id)

        let result = try service.copyWeek(from: "2026-W36", to: "2026-W38", mode: .fillEmpty)

        #expect(result.copied == 2)
        let target = try #require(try service.plan(for: "2026-W38"))
        let newCooked = try #require((target.slots ?? []).first { $0.dayIndex == 0 })
        let newLeftover = try #require((target.slots ?? []).first { $0.dayIndex == 1 })
        #expect(newLeftover.leftoverOfSlotID == newCooked.id)
    }

    @Test func copyWeekSkipsMealsDeletedSinceArchiving() throws {
        let meal = try makeMeal("Chicken fajitas")
        try plantSlot(weekID: "2026-W37", dayIndex: 0, mealType: .dinner, meal: meal)
        try ArchiveService(context: context, now: now, calendar: calendar).archiveEndedWeeks()
        try mealStore.delete(meal)

        let result = try service.copyWeek(from: "2026-W37", to: "2026-W38", mode: .fillEmpty)

        #expect(result.copied == 0)
        #expect(result.skippedDeletedMeals == 1)
    }

    @Test func copyWeekWithAnEmptySourceCreatesNoTargetPlan() throws {
        let result = try service.copyWeek(from: "2026-W36", to: "2026-W38", mode: .fillEmpty)

        #expect(result.copied == 0)
        #expect(result.skippedDeletedMeals == 0)
        #expect(try service.plan(for: "2026-W38") == nil)
        #expect(try context.fetch(FetchDescriptor<WeekPlan>()).isEmpty)
    }

    @Test func assignOnAnEndedTargetWeekThrows() throws {
        let meal = try makeMeal("Chicken fajitas")
        #expect(throws: AppError.weekIsArchived) {
            try service.assign(meal, at: PlanPosition(weekID: "2026-W37", dayIndex: 0, mealType: .dinner))
        }
    }

    // MARK: - Leftovers (M7)

    @Test func leftoverSourceCandidatesFindsAMealCookedWithinThreeDays() throws {
        let meal = try makeMeal("Chicken fajitas")
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner))

        let candidates = try service.leftoverSourceCandidates(
            mealID: meal.id, target: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch)
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.position.dayIndex == 0)
    }

    @Test func leftoverSourceCandidatesWorksAcrossTheWeekBoundary() throws {
        let meal = try makeMeal("Chicken fajitas")
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 6, mealType: .dinner))

        let candidates = try service.leftoverSourceCandidates(
            mealID: meal.id, target: PlanPosition(weekID: "2026-W39", dayIndex: 0, mealType: .lunch)
        )

        #expect(candidates.count == 1)
    }

    @Test func assignAsLeftoversAddsNoDependentsAndSetsTheSourceLink() throws {
        let meal = try makeMeal("Chicken fajitas")
        let cookedPosition = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: cookedPosition)
        let cookedSlot = try #require((try service.plan(for: "2026-W38"))?.slots?.first)

        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch), leftoversOf: cookedSlot.id)

        let leftoverSlot = try #require((try service.plan(for: "2026-W38"))?.slots?.first { $0.dayIndex == 1 })
        #expect(leftoverSlot.leftoverOfSlotID == cookedSlot.id)
        #expect(leftoverSlot.isLeftovers)
    }

    @Test func markAsLeftoversUsesTheNearestCandidate() throws {
        let meal = try makeMeal("Chicken fajitas")
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner))
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch))

        try service.markAsLeftovers(at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch))

        let plan = try #require(try service.plan(for: "2026-W38"))
        let cookedSlot = try #require((plan.slots ?? []).first { $0.dayIndex == 0 })
        let leftoverSlot = try #require((plan.slots ?? []).first { $0.dayIndex == 1 })
        #expect(leftoverSlot.leftoverOfSlotID == cookedSlot.id)
    }

    @Test func markAsLeftoversIsANoOpWithoutACandidate() throws {
        let meal = try makeMeal("Chicken fajitas")
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch))

        try service.markAsLeftovers(at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch))

        let slot = try #require((try service.plan(for: "2026-W38"))?.slots?.first)
        #expect(slot.leftoverOfSlotID == nil)
    }

    @Test func markAsCookedClearsTheSourceLink() throws {
        let meal = try makeMeal("Chicken fajitas")
        let cookedPosition = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: cookedPosition)
        let cookedSlot = try #require((try service.plan(for: "2026-W38"))?.slots?.first)
        let leftoverPosition = PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch)
        try service.assign(meal, at: leftoverPosition, leftoversOf: cookedSlot.id)

        try service.markAsCooked(at: leftoverPosition)

        let slot = try #require((try service.plan(for: "2026-W38"))?.slots?.first { $0.dayIndex == 1 })
        #expect(slot.leftoverOfSlotID == nil)
    }

    @Test func addLeftoversAssignsTheSameMealLinkedToTheSource() throws {
        let meal = try makeMeal("Chicken fajitas")
        let source = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: source)
        let cookedSlot = try #require((try service.plan(for: "2026-W38"))?.slots?.first)

        try service.addLeftovers(from: source, to: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch))

        let leftoverSlot = try #require((try service.plan(for: "2026-W38"))?.slots?.first { $0.dayIndex == 1 })
        #expect(leftoverSlot.meal?.id == meal.id)
        #expect(leftoverSlot.leftoverOfSlotID == cookedSlot.id)
    }

    @Test func sourceLabelDescribesTheCookedSlot() throws {
        let meal = try makeMeal("Chicken fajitas")
        let source = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: source)
        let cookedSlot = try #require((try service.plan(for: "2026-W38"))?.slots?.first)
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch), leftoversOf: cookedSlot.id)
        let leftoverSlot = try #require((try service.plan(for: "2026-W38"))?.slots?.first { $0.dayIndex == 1 })

        #expect(try service.sourceLabel(for: leftoverSlot) == "Mon dinner")
    }

    @Test func isEmptyAndEditableIsTrueForAnEmptySlotInAnEditableWeek() throws {
        #expect(try service.isEmptyAndEditable(PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)))
    }

    @Test func isEmptyAndEditableIsFalseForAFilledSlot() throws {
        let meal = try makeMeal("Chicken fajitas")
        let position = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: position)

        #expect(try service.isEmptyAndEditable(position) == false)
    }

    @Test func isEmptyAndEditableIsFalseForAnEndedWeek() throws {
        #expect(try service.isEmptyAndEditable(PlanPosition(weekID: "2026-W37", dayIndex: 0, mealType: .dinner)) == false)
    }

    @Test func assignmentDecisionNeedsLeftoverPromptWhenThereAreCandidates() throws {
        let meal = try makeMeal("Chicken fajitas")
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner))

        let decision = try service.assignmentDecision(forAssigning: meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch))

        guard case .needsLeftoverPrompt(let candidates) = decision else {
            Issue.record("Expected needsLeftoverPrompt, got \(decision)")
            return
        }
        #expect(candidates.count == 1)
    }

    @Test func assignmentDecisionIsReadyWhenAssigningTheSameMealToTheSameSlot() throws {
        let meal = try makeMeal("Chicken fajitas")
        let position = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: position)

        let decision = try service.assignmentDecision(forAssigning: meal, at: position)

        guard case .readyToAssign = decision else {
            Issue.record("Expected readyToAssign, got \(decision)")
            return
        }
    }

    @Test func assignmentDecisionNeedsDependentPromptWhenReplacingACookedMealWithDependents() throws {
        let meal = try makeMeal("Chicken fajitas")
        let otherMeal = try makeMeal("Veggie chilli")
        let cookedPosition = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: cookedPosition)
        let cookedSlot = try #require((try service.plan(for: "2026-W38"))?.slots?.first)
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch), leftoversOf: cookedSlot.id)

        let decision = try service.dependentDecision(forCookedAssignmentOf: otherMeal, at: cookedPosition)

        guard case .needsDependentPrompt(let dependents) = decision else {
            Issue.record("Expected needsDependentPrompt, got \(decision)")
            return
        }
        #expect(dependents.count == 1)
    }

    @Test func assignWithRemoveDependentsDeletesLeftoversWhenReplacingTheMeal() throws {
        let meal = try makeMeal("Chicken fajitas")
        let otherMeal = try makeMeal("Veggie chilli")
        let cookedPosition = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: cookedPosition)
        let cookedSlot = try #require((try service.plan(for: "2026-W38"))?.slots?.first)
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch), leftoversOf: cookedSlot.id)

        try service.assign(otherMeal, at: cookedPosition, dependents: .remove)

        let plan = try #require(try service.plan(for: "2026-W38"))
        #expect((plan.slots ?? []).count == 1)
        #expect((plan.slots ?? []).first?.meal?.id == otherMeal.id)
    }

    @Test func assignWithKeepAsCookedDetachesLeftoversWhenReplacingTheMeal() throws {
        let meal = try makeMeal("Chicken fajitas")
        let otherMeal = try makeMeal("Veggie chilli")
        let cookedPosition = PlanPosition(weekID: "2026-W38", dayIndex: 0, mealType: .dinner)
        try service.assign(meal, at: cookedPosition)
        let cookedSlot = try #require((try service.plan(for: "2026-W38"))?.slots?.first)
        try service.assign(meal, at: PlanPosition(weekID: "2026-W38", dayIndex: 1, mealType: .lunch), leftoversOf: cookedSlot.id)

        try service.assign(otherMeal, at: cookedPosition, dependents: .keepAsCooked)

        let plan = try #require(try service.plan(for: "2026-W38"))
        #expect((plan.slots ?? []).count == 2)
        let formerLeftover = try #require((plan.slots ?? []).first { $0.dayIndex == 1 })
        #expect(formerLeftover.leftoverOfSlotID == nil)
        #expect(formerLeftover.meal?.id == meal.id)
    }
}
