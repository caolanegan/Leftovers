import Foundation
import SwiftData

@MainActor
struct MealStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func create(from draft: MealDraft) throws -> Meal {
        try ArchiveService(context: context).archiveEndedWeeks()
        let normalized = draft.normalized()
        guard normalized.isValid else { throw AppError.invalidName }

        let meal = Meal(name: normalized.name)
        context.insert(meal)
        try apply(normalized, to: meal)
        try context.save()
        return meal
    }

    func update(_ meal: Meal, from draft: MealDraft) throws {
        try ArchiveService(context: context).archiveEndedWeeks()
        let normalized = draft.normalized()
        guard normalized.isValid else { throw AppError.invalidName }

        meal.name = normalized.name
        try apply(normalized, to: meal)
        try context.save()
    }

    @discardableResult
    func duplicate(_ meal: Meal) throws -> Meal {
        try ArchiveService(context: context).archiveEndedWeeks()
        let copy = Meal(name: "\(meal.name) (copy)")
        copy.mealTypes = meal.mealTypes
        copy.servings = meal.servings
        copy.totalMinutes = meal.totalMinutes
        copy.notes = meal.notes
        copy.photoData = meal.photoData
        copy.thumbnailData = meal.thumbnailData
        copy.goodAsLeftovers = meal.goodAsLeftovers
        copy.isFavorite = false
        context.insert(copy)

        for line in meal.sortedIngredients {
            guard let ingredient = line.ingredient else { continue }
            let newLine = RecipeIngredient(
                ingredient: ingredient,
                quantity: line.quantity,
                unit: line.unit,
                note: line.note,
                sortIndex: line.sortIndex
            )
            newLine.meal = copy
            context.insert(newLine)
        }

        for step in meal.sortedSteps {
            let newStep = InstructionStep(text: step.text, sortIndex: step.sortIndex)
            newStep.meal = copy
            context.insert(newStep)
        }

        try context.save()
        return copy
    }

    func toggleFavorite(_ meal: Meal) throws {
        try ArchiveService(context: context).archiveEndedWeeks()
        meal.isFavorite.toggle()
        meal.updatedAt = .now
        try context.save()
    }

    /// Deletes the meal's slots in non-archived weeks (plus any leftovers that
    /// depend on them), then the meal itself. Archived slots keep their JSON
    /// snapshot and `meal` becomes nil automatically via the `.nullify` rule (§6.6).
    func delete(_ meal: Meal) throws {
        try ArchiveService(context: context).archiveEndedWeeks()

        let weekPlanService = WeekPlanService(context: context)
        for slot in meal.slots ?? [] where slot.weekPlan?.isArchived == false {
            if let weekID = slot.weekPlan?.weekID {
                let position = PlanPosition(weekID: weekID, dayIndex: slot.dayIndex, mealType: slot.mealType)
                for dependent in try weekPlanService.dependentLeftovers(of: position) {
                    context.delete(dependent)
                }
            }
            context.delete(slot)
        }

        context.delete(meal)
        try context.save()
    }

    func upcomingPlanCount(for meal: Meal) -> Int {
        (meal.slots ?? []).filter { $0.weekPlan?.isArchived == false }.count
    }

    @discardableResult
    func addSampleMeals() throws -> Int {
        try ArchiveService(context: context).archiveEndedWeeks()
        let existingNames = Set(try context.fetch(FetchDescriptor<Meal>()).map { NameNormalizer.key($0.name) })
        let ingredientStore = IngredientStore(context: context)
        var added = 0

        for sample in SampleData.meals where !existingNames.contains(NameNormalizer.key(sample.name)) {
            let meal = Meal(name: sample.name)
            meal.mealTypes = sample.types
            meal.servings = sample.servings
            meal.totalMinutes = sample.totalMinutes
            meal.notes = sample.notes
            meal.goodAsLeftovers = sample.goodAsLeftovers
            context.insert(meal)

            for (index, line) in sample.lines.enumerated() {
                let info = SampleData.ingredientInfo(named: line.ingredientName)
                let ingredient = try ingredientStore.findOrCreate(
                    name: line.ingredientName,
                    defaultUnit: info.unit,
                    category: info.category
                )
                let recipeLine = RecipeIngredient(
                    ingredient: ingredient,
                    quantity: line.quantity,
                    unit: line.unit,
                    note: line.note,
                    sortIndex: index
                )
                recipeLine.meal = meal
                context.insert(recipeLine)
            }

            for (index, stepText) in sample.steps.enumerated() {
                let step = InstructionStep(text: stepText, sortIndex: index)
                step.meal = meal
                context.insert(step)
            }

            added += 1
        }

        try context.save()
        return added
    }

    /// Replaces `meal`'s recipe lines and steps with `draft`'s, and updates its scalar fields.
    private func apply(_ draft: MealDraft, to meal: Meal) throws {
        meal.mealTypes = draft.mealTypes
        meal.servings = draft.servings
        meal.totalMinutes = draft.totalMinutes
        meal.notes = draft.notes
        meal.goodAsLeftovers = draft.goodAsLeftovers
        if meal.photoData != draft.photo { meal.photoData = draft.photo }
        if meal.thumbnailData != draft.thumbnail { meal.thumbnailData = draft.thumbnail }
        meal.updatedAt = .now

        for line in meal.ingredients ?? [] { context.delete(line) }
        meal.ingredients = []
        for (index, lineDraft) in draft.lines.enumerated() {
            guard let ingredient = try fetchIngredient(id: lineDraft.ingredientID) else { continue }
            let line = RecipeIngredient(
                ingredient: ingredient,
                quantity: lineDraft.quantity,
                unit: lineDraft.unit,
                note: lineDraft.note,
                sortIndex: index
            )
            line.meal = meal
            context.insert(line)
        }

        for step in meal.steps ?? [] { context.delete(step) }
        meal.steps = []
        for (index, stepDraft) in draft.steps.enumerated() {
            let step = InstructionStep(text: stepDraft.text, sortIndex: index)
            step.meal = meal
            context.insert(step)
        }
    }

    private func fetchIngredient(id: UUID) throws -> Ingredient? {
        var descriptor = FetchDescriptor<Ingredient>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
