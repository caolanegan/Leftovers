import Foundation
import SwiftData

enum DependentLeftoversAction { case remove, keepAsCooked }
struct CopyResult { let copied: Int; let skippedDeletedMeals: Int }

/// `+Leftovers` (M7), `+Randomize` (M8) and `+Shopping` (M9) live alongside
/// this core: reading, slots and copy.
@MainActor
struct WeekPlanService {
    let context: ModelContext
    var now: Date = .now
    var calendar: Calendar = WeekMath.appCalendar

    // MARK: - Reading

    func plan(for weekID: String) throws -> WeekPlan? {
        var descriptor = FetchDescriptor<WeekPlan>(predicate: #Predicate { $0.weekID == weekID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @discardableResult
    func fetchOrCreatePlan(for weekID: String) throws -> WeekPlan {
        try ArchiveService(context: context, now: now, calendar: calendar).archiveEndedWeeks()
        guard !WeekMath.isEnded(weekID, now: now, calendar: calendar) else { throw AppError.weekIsArchived }

        if let existing = try plan(for: weekID) { return existing }
        let newPlan = WeekPlan(weekID: weekID)
        context.insert(newPlan)
        try context.save()
        return newPlan
    }

    func isReadOnly(_ weekID: String) -> Bool {
        WeekMath.isEnded(weekID, now: now, calendar: calendar)
    }

    func mealIDs(inWeek weekID: String) throws -> Set<UUID> {
        Set(try filledSlots(in: weekID).map(\.mealID))
    }

    func occurrences(around weekID: String) throws -> [PlanOccurrence] {
        let previous = WeekMath.weekID(weekID, adding: -1, calendar: calendar)
        return try (filledSlots(in: previous) + filledSlots(in: weekID)).map {
            PlanOccurrence(slotID: $0.slotID, position: $0.position, mealID: $0.mealID, isLeftovers: $0.leftoverOfSlotID != nil)
        }
    }

    // MARK: - Slots

    /// `dependents` resolves what happens to slots that are leftovers of the
    /// slot at `position`, when this call changes that slot's meal (§8.2)
    /// — not in the spec's `assign` skeleton, which has no way to carry the
    /// dependent-leftovers dialog's (§10.3 B) choice through. Assigning the
    /// same meal, or to a slot that's currently leftovers, never touches
    /// dependents, so `dependents` is ignored (its default is harmless) in
    /// every other case. The randomiser's `.replaceAll` (M8, §8.2 step 3)
    /// must pass `.remove` here — it always deletes a replaced cooked slot's
    /// dependents, never keeps them as cooked.
    func assign(
        _ meal: Meal, at position: PlanPosition, leftoversOf sourceSlotID: UUID? = nil,
        dependents: DependentLeftoversAction = .keepAsCooked
    ) throws {
        let plan = try fetchOrCreatePlan(for: position.weekID)
        if let existing = slot(at: position, in: plan) {
            if !existing.isLeftovers, existing.meal?.id != meal.id {
                try applyDependents(dependents, of: position)
            }
            // This slot is itself becoming leftovers, so nothing should chain
            // through it — anything that was leftovers of it now points
            // straight at its own new source instead (§7.7: leftovers always
            // point at a cooked slot, never at another leftovers slot).
            if let sourceSlotID {
                try repointDependents(of: existing.id, to: sourceSlotID)
            }
            existing.meal = meal
            existing.leftoverOfSlotID = sourceSlotID
        } else {
            let newSlot = MealSlot(dayIndex: position.dayIndex, mealType: position.mealType)
            newSlot.weekPlan = plan
            newSlot.meal = meal
            newSlot.leftoverOfSlotID = sourceSlotID
            context.insert(newSlot)
        }
        try context.save()
    }

    func clearSlot(at position: PlanPosition, dependents: DependentLeftoversAction) throws {
        try ArchiveService(context: context, now: now, calendar: calendar).archiveEndedWeeks()
        guard !WeekMath.isEnded(position.weekID, now: now, calendar: calendar) else { throw AppError.weekIsArchived }
        guard let plan = try plan(for: position.weekID), let target = slot(at: position, in: plan) else { return }

        try applyDependents(dependents, of: position)
        context.delete(target)
        try context.save()
    }

    func dependentLeftovers(of position: PlanPosition) throws -> [MealSlot] {
        guard let plan = try plan(for: position.weekID), let target = slot(at: position, in: plan) else { return [] }
        let targetID = target.id
        let descriptor = FetchDescriptor<MealSlot>(predicate: #Predicate { $0.leftoverOfSlotID == targetID })
        return try context.fetch(descriptor)
    }

    func clearWeek(_ weekID: String) throws {
        try ArchiveService(context: context, now: now, calendar: calendar).archiveEndedWeeks()
        guard !WeekMath.isEnded(weekID, now: now, calendar: calendar) else { throw AppError.weekIsArchived }
        guard let plan = try plan(for: weekID) else { return }

        let slotsToClear = plan.slots ?? []
        for slot in slotsToClear {
            let position = PlanPosition(weekID: weekID, dayIndex: slot.dayIndex, mealType: slot.mealType)
            try applyDependents(.remove, of: position)
        }
        for slot in slotsToClear { context.delete(slot) }
        for item in plan.manualItems ?? [] { context.delete(item) }
        for state in plan.itemStates ?? [] { context.delete(state) }
        plan.lastSharedSignature = nil
        try context.save()
    }

    /// Whether clearing `weekID` would also remove leftovers that depend on
    /// one of its slots — in this week or (Sunday → Monday) the next one.
    func weekHasDependentLeftovers(_ weekID: String) throws -> Bool {
        guard let plan = try plan(for: weekID) else { return false }
        for slot in plan.slots ?? [] {
            let position = PlanPosition(weekID: weekID, dayIndex: slot.dayIndex, mealType: slot.mealType)
            if try !dependentLeftovers(of: position).isEmpty { return true }
        }
        return false
    }

    func copyWeek(from source: String, to target: String, mode: RandomizeMode) throws -> CopyResult {
        try ArchiveService(context: context, now: now, calendar: calendar).archiveEndedWeeks()
        let sourceSlots = try filledSlots(in: source)
        guard !sourceSlots.isEmpty else { return CopyResult(copied: 0, skippedDeletedMeals: 0) }

        let targetPlan = try fetchOrCreatePlan(for: target)

        if mode == .replaceAll {
            let existingSlots = targetPlan.slots ?? []
            for existing in existingSlots {
                let position = PlanPosition(weekID: target, dayIndex: existing.dayIndex, mealType: existing.mealType)
                try applyDependents(.remove, of: position)
            }
            for existing in existingSlots { context.delete(existing) }
            targetPlan.slots = []
        }

        var skippedDeletedMeals = 0
        var oldIDToNewSlot: [UUID: MealSlot] = [:]
        var pendingLeftoverLinks: [(newSlot: MealSlot, oldSourceID: UUID)] = []

        for info in sourceSlots {
            guard let meal = try fetchMeal(id: info.mealID) else {
                skippedDeletedMeals += 1
                continue
            }

            let position = PlanPosition(weekID: target, dayIndex: info.position.dayIndex, mealType: info.position.mealType)
            // `.replaceAll` already cleared every existing target slot above, so
            // there's nothing to look up (and nothing left to accidentally reuse).
            let existingTargetSlot = mode == .replaceAll ? nil : slot(at: position, in: targetPlan)
            if mode == .fillEmpty, existingTargetSlot != nil { continue }

            let newSlot: MealSlot
            if let existingTargetSlot {
                newSlot = existingTargetSlot
            } else {
                newSlot = MealSlot(dayIndex: position.dayIndex, mealType: position.mealType)
                newSlot.weekPlan = targetPlan
                context.insert(newSlot)
            }
            newSlot.meal = meal
            newSlot.leftoverOfSlotID = nil

            oldIDToNewSlot[info.slotID] = newSlot
            if let leftoverOf = info.leftoverOfSlotID {
                pendingLeftoverLinks.append((newSlot, leftoverOf))
            }
        }

        for (newSlot, oldSourceID) in pendingLeftoverLinks {
            if let mappedSource = oldIDToNewSlot[oldSourceID] {
                newSlot.leftoverOfSlotID = mappedSource.id
            }
        }

        try context.save()
        return CopyResult(copied: oldIDToNewSlot.count, skippedDeletedMeals: skippedDeletedMeals)
    }

    // MARK: - Private

    private struct FilledSlot {
        let slotID: UUID
        let position: PlanPosition
        let mealID: UUID
        let leftoverOfSlotID: UUID?
    }

    /// Internal, not `private`, so `WeekPlanService+Leftovers.swift` (§5.2's
    /// extension-per-file split) can reuse it.
    func slot(at position: PlanPosition, in plan: WeekPlan) -> MealSlot? {
        (plan.slots ?? []).first { $0.dayIndex == position.dayIndex && $0.mealType == position.mealType }
    }

    private func filledSlots(in weekID: String) throws -> [FilledSlot] {
        guard let plan = try plan(for: weekID) else { return [] }

        if plan.isArchived {
            let archiveService = ArchiveService(context: context, now: now, calendar: calendar)
            return (plan.slots ?? []).compactMap { slot in
                guard let snapshot = archiveService.archivedSlot(slot), let mealID = snapshot.mealID else { return nil }
                let position = PlanPosition(weekID: weekID, dayIndex: slot.dayIndex, mealType: slot.mealType)
                return FilledSlot(slotID: slot.id, position: position, mealID: mealID, leftoverOfSlotID: snapshot.leftoverOfSlotID)
            }
        }

        return (plan.slots ?? []).compactMap { slot in
            guard let mealID = slot.meal?.id else { return nil }
            let position = PlanPosition(weekID: weekID, dayIndex: slot.dayIndex, mealType: slot.mealType)
            return FilledSlot(slotID: slot.id, position: position, mealID: mealID, leftoverOfSlotID: slot.leftoverOfSlotID)
        }
    }

    private func applyDependents(_ action: DependentLeftoversAction, of position: PlanPosition) throws {
        for dependent in try dependentLeftovers(of: position) {
            switch action {
            case .remove: context.delete(dependent)
            case .keepAsCooked: dependent.leftoverOfSlotID = nil
            }
        }
    }

    private func repointDependents(of slotID: UUID, to newSourceSlotID: UUID) throws {
        let descriptor = FetchDescriptor<MealSlot>(predicate: #Predicate<MealSlot> { $0.leftoverOfSlotID == slotID })
        for dependent in try context.fetch(descriptor) {
            dependent.leftoverOfSlotID = newSourceSlotID
        }
    }

    /// Internal, not `private`, so `WeekPlanService+Leftovers.swift` can reuse
    /// it to check a meal's `goodAsLeftovers` flag (§7.7 v1.3).
    func fetchMeal(id: UUID) throws -> Meal? {
        var descriptor = FetchDescriptor<Meal>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
