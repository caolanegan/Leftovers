import Foundation
import Testing
import SwiftData
@testable import MealPlanner

@MainActor
struct ArchiveServiceTests {
    let container: ModelContainer
    let context: ModelContext
    let mealStore: MealStore
    let ingredientStore: IngredientStore
    let calendar = WeekMath.appCalendar

    /// A moment inside week 2026-W38, so 2026-W37 has ended and 2026-W38 hasn't.
    let now: Date

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        context = container.mainContext
        mealStore = MealStore(context: context)
        ingredientStore = IngredientStore(context: context)

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        now = try #require(formatter.date(from: "2026-09-14 09:00"))
    }

    private func archiveService() -> ArchiveService {
        ArchiveService(context: context, now: now, calendar: calendar)
    }

    private func weekPlanService() -> WeekPlanService {
        WeekPlanService(context: context, now: now, calendar: calendar)
    }

    @discardableResult
    private func makeMeal(name: String = "Spaghetti bolognese") throws -> Meal {
        let onion = try ingredientStore.create(name: "Onion", defaultUnit: .item, category: .produce)
        var draft = MealDraft()
        draft.name = name
        draft.mealTypes = [.dinner]
        draft.lines = [
            RecipeLineDraft(id: UUID(), ingredientID: onion.id, ingredientName: onion.name, quantity: 1, unit: .item, note: "chopped"),
        ]
        return try mealStore.create(from: draft)
    }

    /// Plants a slot directly (bypassing services) in a past, ended week.
    private func plantEndedWeekSlot(meal: Meal) throws -> (plan: WeekPlan, slot: MealSlot) {
        let plan = WeekPlan(weekID: "2026-W37")
        context.insert(plan)
        let slot = MealSlot(dayIndex: 0, mealType: .dinner)
        slot.weekPlan = plan
        slot.meal = meal
        context.insert(slot)
        try context.save()
        return (plan, slot)
    }

    @Test func archiveEndedWeeksArchivesOnlyEndedWeeks() throws {
        let meal = try makeMeal()
        let (pastPlan, _) = try plantEndedWeekSlot(meal: meal)
        let currentPlan = WeekPlan(weekID: "2026-W38")
        context.insert(currentPlan)
        try context.save()

        let count = try archiveService().archiveEndedWeeks()

        #expect(count == 1)
        #expect(pastPlan.isArchived == true)
        #expect(currentPlan.isArchived == false)
    }

    @Test func editingMealAfterArchiveDoesNotChangeSnapshot() throws {
        let meal = try makeMeal()
        let (_, slot) = try plantEndedWeekSlot(meal: meal)
        try archiveService().archiveEndedWeeks()

        let before = try #require(archiveService().archivedSlot(slot))
        #expect(before.mealName == "Spaghetti bolognese")

        var draft = MealDraft(meal: meal)
        draft.name = "Renamed meal"
        try mealStore.update(meal, from: draft)

        let after = try #require(archiveService().archivedSlot(slot))
        #expect(after.mealName == "Spaghetti bolognese")
        #expect(after == before)
    }

    @Test func deletingMealAfterArchiveKeepsSnapshotName() throws {
        let meal = try makeMeal()
        let (_, slot) = try plantEndedWeekSlot(meal: meal)
        try archiveService().archiveEndedWeeks()

        try mealStore.delete(meal)

        let snapshot = try #require(archiveService().archivedSlot(slot))
        #expect(snapshot.mealName == "Spaghetti bolognese")
        #expect(slot.meal == nil)
    }

    @Test func renamingIngredientAfterArchiveDoesNotChangeArchivedIngredients() throws {
        let meal = try makeMeal()
        let (_, slot) = try plantEndedWeekSlot(meal: meal)
        try archiveService().archiveEndedWeeks()

        let onion = try #require(try ingredientStore.find(named: "Onion"))
        try ingredientStore.update(onion, name: "Brown onion", defaultUnit: onion.defaultUnit, category: onion.category)

        let snapshot = try #require(archiveService().archivedSlot(slot))
        #expect(snapshot.ingredients.map(\.name) == ["Onion"])
    }

    @Test func assignOnAnEndedWeekThrowsWeekIsArchived() throws {
        let meal = try makeMeal()
        let position = PlanPosition(weekID: "2026-W37", dayIndex: 0, mealType: .dinner)

        #expect(throws: AppError.weekIsArchived) {
            try weekPlanService().assign(meal, at: position)
        }
    }

    @Test func archivingIsIdempotent() throws {
        let meal = try makeMeal()
        let (pastPlan, _) = try plantEndedWeekSlot(meal: meal)

        let first = try archiveService().archiveEndedWeeks()
        let second = try archiveService().archiveEndedWeeks()

        #expect(first == 1)
        #expect(second == 0)
        #expect(pastPlan.isArchived == true)
    }
}
