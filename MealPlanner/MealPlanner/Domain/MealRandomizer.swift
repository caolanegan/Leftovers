import Foundation

enum RandomizeMode: String, CaseIterable, Sendable {
    case fillEmpty, replaceAll
}

/// A day/meal-type slot, used by the randomiser (§7.6) — distinct from
/// `PlanPosition` (`LeftoverRules.swift`) since it isn't tied to a week.
struct SlotKey: Hashable, Comparable, Sendable {
    let dayIndex: Int
    let mealType: MealType

    static func < (lhs: SlotKey, rhs: SlotKey) -> Bool {
        if lhs.dayIndex != rhs.dayIndex { return lhs.dayIndex < rhs.dayIndex }
        return lhs.mealType < rhs.mealType
    }
}

struct RandomizeResult: Equatable, Sendable {
    var assignments: [SlotKey: UUID]        // only slots to (re)assign
    var skippedNoCandidates: [SlotKey]       // targets left alone because the pool was empty
}

enum MealRandomizer {
    /// §7.6's algorithm: never last week's meals; avoid repeats this week;
    /// failing that, avoid the same meal on neighbouring days; and when
    /// re-rolling, try to give something different from before.
    static func randomize(
        targetSlots: [SlotKey],
        current: [SlotKey: UUID],
        lockedSlots: Set<SlotKey>,
        candidates: [MealType: [UUID]],
        excludedMealIDs: Set<UUID>,
        mode: RandomizeMode,
        using rng: inout some RandomNumberGenerator
    ) -> RandomizeResult {
        let targets = targetSlots.filter { !lockedSlots.contains($0) }.sorted()
        var week = current
        let previous = current
        if mode == .replaceAll {
            for target in targets { week[target] = nil }
        }

        var assignments: [SlotKey: UUID] = [:]
        var skippedNoCandidates: [SlotKey] = []

        for slot in targets {
            if mode == .fillEmpty, week[slot] != nil { continue }

            let pool = (candidates[slot.mealType] ?? []).filter { !excludedMealIDs.contains($0) }
            guard !pool.isEmpty else {
                skippedNoCandidates.append(slot)
                continue
            }

            let usedInWeek = Set(week.filter { $0.key != slot }.values)
            let nearby = Set(week.filter { $0.key != slot && abs($0.key.dayIndex - slot.dayIndex) <= 1 }.values)
            let prev = previous[slot]

            let tiers: [[UUID]] = [
                pool.filter { !usedInWeek.contains($0) && $0 != prev },
                pool.filter { !nearby.contains($0) && $0 != prev },
                pool.filter { $0 != prev },
                pool
            ]
            guard let tier = tiers.first(where: { !$0.isEmpty }), let pick = tier.randomElement(using: &rng) else { continue }

            week[slot] = pick
            assignments[slot] = pick
        }

        return RandomizeResult(assignments: assignments, skippedNoCandidates: skippedNoCandidates)
    }

    /// Copy for the "not enough candidates" alert (§10.1), covering one or several
    /// meal types — mirrors `LeftoverRules`'s own copy-builder precedent.
    static func skippedCandidatesMessage(for types: Set<MealType>) -> String {
        let names = MealType.allCases.filter { types.contains($0) }.map { $0.pluralName.lowercased() }
        let joined = joined(names)
        return "Not enough \(joined) to choose from. Meals from last week are left out — add more \(joined) or pick one yourself."
    }

    private static func joined(_ items: [String]) -> String {
        guard let last = items.last else { return "" }
        guard items.count > 1 else { return last }
        return "\(items.dropLast().joined(separator: ", ")) and \(last)"
    }
}
