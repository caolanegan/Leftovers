import Foundation
import SwiftData

/// Whether an assignment (or an about-to-happen one) needs a prompt before
/// it can go ahead — the shared sequencing behind §10.2, §10.3 and §10.8:
/// check for leftover-source candidates first, then (once cooked) whether
/// the slot's existing cooked meal has dependents that need resolving.
enum AssignmentDecision {
    case needsLeftoverPrompt([PlanOccurrence])
    case needsDependentPrompt([MealSlot])
    case readyToAssign
}

extension WeekPlanService {
    /// `[]` without consulting `LeftoverRules` when the meal isn't
    /// `goodAsLeftovers` (§7.7 v1.3) — `LeftoverRules` stays a pure function
    /// of occurrences and doesn't know about the flag; this is where it's applied.
    func leftoverSourceCandidates(mealID: UUID, target: PlanPosition) throws -> [PlanOccurrence] {
        guard try fetchMeal(id: mealID)?.goodAsLeftovers == true else { return [] }
        return LeftoverRules.sourceCandidates(
            mealID: mealID, target: target, occurrences: try occurrences(around: target.weekID), calendar: calendar
        )
    }

    /// Uses the nearest candidate; a no-op if there isn't one.
    func markAsLeftovers(at position: PlanPosition) throws {
        guard let plan = try plan(for: position.weekID), let slot = slot(at: position, in: plan),
              let meal = slot.meal, !slot.isLeftovers
        else { return }
        guard let nearest = try leftoverSourceCandidates(mealID: meal.id, target: position).first else { return }
        try assign(meal, at: position, leftoversOf: nearest.slotID)
    }

    func markAsCooked(at position: PlanPosition) throws {
        guard let plan = try plan(for: position.weekID), let slot = slot(at: position, in: plan),
              let meal = slot.meal
        else { return }
        try assign(meal, at: position, leftoversOf: nil)
    }

    /// `target` must be empty and in an editable week (§10.1's "Leftovers for
    /// Tomorrow's Lunch/Dinner" only offers this when that's already true).
    /// No-op if the meal isn't `goodAsLeftovers` (§7.7 v1.3).
    func addLeftovers(from source: PlanPosition, to target: PlanPosition) throws {
        guard let sourcePlan = try plan(for: source.weekID), let sourceSlot = slot(at: source, in: sourcePlan),
              let meal = sourceSlot.meal, meal.goodAsLeftovers
        else { return }
        try assign(meal, at: target, leftoversOf: sourceSlot.id)
    }

    /// Human label for a slot's leftover source, e.g. "Mon dinner".
    func sourceLabel(for slot: MealSlot) throws -> String? {
        guard let sourceID = slot.leftoverOfSlotID else { return nil }
        var descriptor = FetchDescriptor<MealSlot>(predicate: #Predicate<MealSlot> { $0.id == sourceID })
        descriptor.fetchLimit = 1
        guard let source = try context.fetch(descriptor).first, let weekID = source.weekPlan?.weekID else { return nil }
        return LeftoverRules.label(for: PlanPosition(weekID: weekID, dayIndex: source.dayIndex, mealType: source.mealType))
    }

    /// Whether `position`'s slot is empty, in an editable (non-ended) week.
    func isEmptyAndEditable(_ position: PlanPosition) throws -> Bool {
        guard !isReadOnly(position.weekID) else { return false }
        guard let plan = try plan(for: position.weekID) else { return true }
        return slot(at: position, in: plan) == nil
    }

    /// The full decision behind assigning `meal` at `position` (§10.2, §10.3, §10.8).
    func assignmentDecision(forAssigning meal: Meal, at position: PlanPosition) throws -> AssignmentDecision {
        let candidates = try leftoverSourceCandidates(mealID: meal.id, target: position)
        if !candidates.isEmpty { return .needsLeftoverPrompt(candidates) }
        return try dependentDecision(forCookedAssignmentOf: meal, at: position)
    }

    /// Whether assigning `meal` as **cooked** at `position` needs the
    /// dependent-leftovers dialog (§10.3 B) first — i.e. whether it would
    /// change a cooked slot's meal while leftovers depend on it.
    func dependentDecision(forCookedAssignmentOf meal: Meal, at position: PlanPosition) throws -> AssignmentDecision {
        guard let plan = try plan(for: position.weekID), let existing = slot(at: position, in: plan),
              !existing.isLeftovers, existing.meal?.id != meal.id
        else { return .readyToAssign }
        let dependents = try dependentLeftovers(of: position)
        return dependents.isEmpty ? .readyToAssign : .needsDependentPrompt(dependents)
    }
}
