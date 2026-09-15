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

    @Test func assignOnAnEndedTargetWeekThrows() throws {
        let meal = try makeMeal("Chicken fajitas")
        #expect(throws: AppError.weekIsArchived) {
            try service.assign(meal, at: PlanPosition(weekID: "2026-W37", dayIndex: 0, mealType: .dinner))
        }
    }
}
