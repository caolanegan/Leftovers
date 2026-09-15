import Foundation
import SwiftData

@MainActor
struct IngredientStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func all() throws -> [Ingredient] {
        try context.fetch(FetchDescriptor<Ingredient>())
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func search(_ text: String) throws -> [Ingredient] {
        let key = NameNormalizer.key(text)
        guard !key.isEmpty else { return try all() }

        return try all()
            .filter { NameNormalizer.key($0.name).contains(key) }
            .sorted { lhs, rhs in
                let lhsIsPrefix = NameNormalizer.key(lhs.name).hasPrefix(key)
                let rhsIsPrefix = NameNormalizer.key(rhs.name).hasPrefix(key)
                guard lhsIsPrefix == rhsIsPrefix else { return lhsIsPrefix }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    func find(named name: String) throws -> Ingredient? {
        let key = NameNormalizer.key(name)
        return try all().first { NameNormalizer.key($0.name) == key }
    }

    @discardableResult
    func create(name: String, defaultUnit: IngredientUnit, category: ShoppingCategory) throws -> Ingredient {
        try ArchiveService(context: context).archiveEndedWeeks()
        let cleaned = NameNormalizer.clean(name)
        guard !cleaned.isEmpty else { throw AppError.invalidName }
        if let existing = try find(named: cleaned) {
            throw AppError.duplicateIngredientName(existingName: existing.name)
        }

        let ingredient = Ingredient(name: cleaned, defaultUnit: defaultUnit, category: category)
        context.insert(ingredient)
        try context.save()
        return ingredient
    }

    func update(_ ingredient: Ingredient, name: String, defaultUnit: IngredientUnit, category: ShoppingCategory) throws {
        try ArchiveService(context: context).archiveEndedWeeks()
        let cleaned = NameNormalizer.clean(name)
        guard !cleaned.isEmpty else { throw AppError.invalidName }
        if let existing = try find(named: cleaned), existing.id != ingredient.id {
            throw AppError.duplicateIngredientName(existingName: existing.name)
        }

        ingredient.name = cleaned
        ingredient.defaultUnit = defaultUnit
        ingredient.category = category
        ingredient.updatedAt = .now
        try context.save()
    }

    func delete(_ ingredient: Ingredient) throws {
        try ArchiveService(context: context).archiveEndedWeeks()
        let mealCount = ingredient.usedInMeals.count
        guard mealCount == 0 else { throw AppError.ingredientInUse(mealCount: mealCount) }

        for item in ingredient.manualUses ?? [] {
            guard let weekPlan = item.weekPlan, !weekPlan.isArchived else { continue }
            context.delete(item)
        }

        context.delete(ingredient)
        try context.save()
    }

    func merge(_ source: Ingredient, into target: Ingredient) throws {
        try ArchiveService(context: context).archiveEndedWeeks()
        guard source.id != target.id else { return }

        for line in source.recipeUses ?? [] {
            line.ingredient = target
        }

        for sourceItem in source.manualUses ?? [] {
            guard let weekPlan = sourceItem.weekPlan, !weekPlan.isArchived else { continue }

            if let targetItem = (weekPlan.manualItems ?? []).first(where: { $0.ingredient?.id == target.id }) {
                if let sourceQuantity = sourceItem.quantity,
                   sourceItem.unit.baseUnit == targetItem.unit.baseUnit {
                    let sourceBaseAmount = sourceQuantity * sourceItem.unit.toBaseMultiplier
                    let targetBaseAmount = (targetItem.quantity ?? 0) * targetItem.unit.toBaseMultiplier
                    targetItem.quantity = (targetBaseAmount + sourceBaseAmount) / targetItem.unit.toBaseMultiplier
                }
                context.delete(sourceItem)
            } else {
                sourceItem.ingredient = target
            }
        }

        let sourceKey = source.id.uuidString
        let nonArchivedPlans = try context.fetch(FetchDescriptor<WeekPlan>()).filter { !$0.isArchived }
        for weekPlan in nonArchivedPlans {
            for state in (weekPlan.itemStates ?? []) where state.itemKey == sourceKey {
                context.delete(state)
            }
        }

        context.delete(source)
        try context.save()
    }

    @discardableResult
    func findOrCreate(name: String, defaultUnit: IngredientUnit, category: ShoppingCategory) throws -> Ingredient {
        if let existing = try find(named: name) {
            return existing
        }
        return try create(name: name, defaultUnit: defaultUnit, category: category)
    }
}
