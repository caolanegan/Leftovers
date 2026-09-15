import Foundation
import SwiftData

struct RandomizeOutcome { let assigned: Int; let skippedTypes: Set<MealType>; let removedLeftovers: Int }

extension WeekPlanService {
    /// §8.2's 5-step algorithm: delete dependents of replaced cooked slots,
    /// lock leftover targets whose source isn't also a target, run
    /// `MealRandomizer`, apply the result and save once.
    func randomize(weekID: String, slots: [SlotKey], mode: RandomizeMode) throws -> RandomizeOutcome {
        try ArchiveService(context: context, now: now, calendar: calendar).archiveEndedWeeks()
        guard !WeekMath.isEnded(weekID, now: now, calendar: calendar) else { throw AppError.weekIsArchived }

        let plan = try fetchOrCreatePlan(for: weekID)
        var slotByKey: [SlotKey: MealSlot] = [:]
        for existing in plan.slots ?? [] {
            slotByKey[SlotKey(dayIndex: existing.dayIndex, mealType: existing.mealType)] = existing
        }

        var lockedSlots: Set<SlotKey> = []
        var deletedSlotIDs: Set<UUID> = []
        var removedLeftovers = 0
        let targetSet = Set(slots)

        if mode == .replaceAll {
            for key in slots {
                guard let slot = slotByKey[key], !slot.isLeftovers else { continue }
                let position = PlanPosition(weekID: weekID, dayIndex: key.dayIndex, mealType: key.mealType)
                for dependent in try dependentLeftovers(of: position) {
                    deletedSlotIDs.insert(dependent.id)
                    context.delete(dependent)
                    removedLeftovers += 1
                }
            }
            for key in slots {
                guard let slot = slotByKey[key], slot.isLeftovers, let sourceID = slot.leftoverOfSlotID else { continue }
                let sourceKey = slotByKey.first { $0.value.id == sourceID }?.key
                if sourceKey == nil || !targetSet.contains(sourceKey!) {
                    lockedSlots.insert(key)
                }
            }
        }

        var current: [SlotKey: UUID] = [:]
        for (key, slot) in slotByKey where !deletedSlotIDs.contains(slot.id) {
            if let mealID = slot.meal?.id { current[key] = mealID }
        }

        let excludedMealIDs = try mealIDs(inWeek: WeekMath.weekID(weekID, adding: -1, calendar: calendar))
        var rng = SystemRandomNumberGenerator()
        let result = MealRandomizer.randomize(
            targetSlots: slots, current: current, lockedSlots: lockedSlots,
            candidates: try candidatesByMealType(), excludedMealIDs: excludedMealIDs, mode: mode, using: &rng
        )

        for (key, mealID) in result.assignments {
            guard let meal = try fetchMeal(id: mealID) else { continue }
            if let existing = slotByKey[key], !deletedSlotIDs.contains(existing.id) {
                existing.meal = meal
                existing.leftoverOfSlotID = nil
            } else {
                let newSlot = MealSlot(dayIndex: key.dayIndex, mealType: key.mealType)
                newSlot.weekPlan = plan
                newSlot.meal = meal
                context.insert(newSlot)
            }
        }

        try context.save()
        let skippedTypes = Set(result.skippedNoCandidates.map(\.mealType))
        return RandomizeOutcome(assigned: result.assignments.count, skippedTypes: skippedTypes, removedLeftovers: removedLeftovers)
    }

    /// A single random pick for one slot (row/picker Shuffle, §10.1/§10.2) — the
    /// caller still runs the normal `dependentDecision`/`assign` flow so a
    /// cooked slot with dependents gets the shared dependent-leftovers dialog,
    /// same as any other reassignment (§14 "Removing, changing or shuffling a
    /// cooked meal with leftovers").
    func randomMeal(for position: PlanPosition) throws -> Meal? {
        let key = SlotKey(dayIndex: position.dayIndex, mealType: position.mealType)
        let candidates = try candidateIDs(suiting: position.mealType)
        guard !candidates.isEmpty else { return nil }

        let excludedMealIDs = try mealIDs(inWeek: WeekMath.weekID(position.weekID, adding: -1, calendar: calendar))
        var current: [SlotKey: UUID] = [:]
        if let plan = try plan(for: position.weekID) {
            for slot in plan.slots ?? [] {
                if let mealID = slot.meal?.id {
                    current[SlotKey(dayIndex: slot.dayIndex, mealType: slot.mealType)] = mealID
                }
            }
        }

        var rng = SystemRandomNumberGenerator()
        let result = MealRandomizer.randomize(
            targetSlots: [key], current: current, lockedSlots: [],
            candidates: [position.mealType: candidates], excludedMealIDs: excludedMealIDs, mode: .replaceAll, using: &rng
        )
        guard let mealID = result.assignments[key] else { return nil }
        return try fetchMeal(id: mealID)
    }

    private func candidateIDs(suiting type: MealType) throws -> [UUID] {
        try context.fetch(FetchDescriptor<Meal>())
            .filter { $0.suits(type) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map(\.id)
    }

    private func candidatesByMealType() throws -> [MealType: [UUID]] {
        let meals = try context.fetch(FetchDescriptor<Meal>())
        var result: [MealType: [UUID]] = [:]
        for type in MealType.allCases {
            result[type] = meals.filter { $0.suits(type) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .map(\.id)
        }
        return result
    }
}
