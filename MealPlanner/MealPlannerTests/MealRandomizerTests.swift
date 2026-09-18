import Testing
import Foundation
@testable import Leftovers

/// Deterministic RNG for reproducible tests (§7.6 "Required tests (seeded `SplitMix64`)").
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@MainActor
struct MealRandomizerTests {
    private func dinnerSlots(_ days: Range<Int> = 0..<7) -> [SlotKey] {
        days.map { SlotKey(dayIndex: $0, mealType: .dinner) }
    }

    @Test func fillEmptyNeverTouchesFilledSlotsAndSkipsLockedSlots() {
        let filled = SlotKey(dayIndex: 0, mealType: .dinner)
        let empty = SlotKey(dayIndex: 1, mealType: .dinner)
        let locked = SlotKey(dayIndex: 2, mealType: .dinner)
        let existingMeal = UUID()
        let candidate = UUID()
        var rng = SplitMix64(seed: 1)

        let result = MealRandomizer.randomize(
            targetSlots: [filled, empty, locked],
            current: [filled: existingMeal],
            lockedSlots: [locked],
            candidates: [.dinner: [candidate]],
            excludedMealIDs: [],
            mode: .fillEmpty,
            using: &rng
        )

        #expect(result.assignments[filled] == nil)
        #expect(result.assignments[locked] == nil)
        #expect(result.assignments[empty] == candidate)
    }

    @Test func excludedMealsAreNeverPickedEvenWhenThatMeansSkippingEveryTarget() {
        let candidates = [UUID(), UUID(), UUID()]
        var rng = SplitMix64(seed: 2)

        let result = MealRandomizer.randomize(
            targetSlots: dinnerSlots(),
            current: [:],
            lockedSlots: [],
            candidates: [.dinner: candidates],
            excludedMealIDs: Set(candidates),
            mode: .fillEmpty,
            using: &rng
        )

        #expect(result.assignments.isEmpty)
        #expect(result.skippedNoCandidates.count == 7)
    }

    @Test func sevenCandidatesForSevenEmptyDinnerSlotsGivesSevenDifferentMeals() {
        let candidates = (0..<7).map { _ in UUID() }
        var rng = SplitMix64(seed: 3)

        let result = MealRandomizer.randomize(
            targetSlots: dinnerSlots(),
            current: [:],
            lockedSlots: [],
            candidates: [.dinner: candidates],
            excludedMealIDs: [],
            mode: .fillEmpty,
            using: &rng
        )

        #expect(Set(result.assignments.values).count == 7)
    }

    @Test func threeCandidatesForSevenEmptyDinnerSlotsNeverRepeatsOnConsecutiveDays() {
        let candidates = (0..<3).map { _ in UUID() }
        var rng = SplitMix64(seed: 4)

        let result = MealRandomizer.randomize(
            targetSlots: dinnerSlots(),
            current: [:],
            lockedSlots: [],
            candidates: [.dinner: candidates],
            excludedMealIDs: [],
            mode: .fillEmpty,
            using: &rng
        )

        for day in 0..<6 {
            let today = result.assignments[SlotKey(dayIndex: day, mealType: .dinner)]
            let tomorrow = result.assignments[SlotKey(dayIndex: day + 1, mealType: .dinner)]
            #expect(today != nil && tomorrow != nil)
            #expect(today != tomorrow)
        }
    }

    @Test func oneCandidateFillsEverySlot() {
        let onlyCandidate = UUID()
        var rng = SplitMix64(seed: 5)

        let result = MealRandomizer.randomize(
            targetSlots: dinnerSlots(),
            current: [:],
            lockedSlots: [],
            candidates: [.dinner: [onlyCandidate]],
            excludedMealIDs: [],
            mode: .fillEmpty,
            using: &rng
        )

        #expect(result.assignments.count == 7)
        #expect(result.assignments.values.allSatisfy { $0 == onlyCandidate })
    }

    @Test func replaceAllOnASingleSlotOnlyChangesThatSlot() throws {
        let candidates = (0..<10).map { _ in UUID() }
        var current: [SlotKey: UUID] = [:]
        for day in 0..<7 {
            current[SlotKey(dayIndex: day, mealType: .dinner)] = candidates[day]
        }
        let tuesday = SlotKey(dayIndex: 1, mealType: .dinner)
        var rng = SplitMix64(seed: 6)

        let result = MealRandomizer.randomize(
            targetSlots: [tuesday],
            current: current,
            lockedSlots: [],
            candidates: [.dinner: candidates],
            excludedMealIDs: [],
            mode: .replaceAll,
            using: &rng
        )

        #expect(result.assignments.count == 1)
        let newMeal = try #require(result.assignments[tuesday])
        #expect(newMeal != current[tuesday])
        let usedElsewhere = current.filter { $0.key != tuesday }.values
        #expect(!usedElsewhere.contains(newMeal))
    }

    @Test func sameSeedGivesTheSameResult() {
        let candidates = (0..<3).map { _ in UUID() }
        var rngA = SplitMix64(seed: 42)
        var rngB = SplitMix64(seed: 42)

        let resultA = MealRandomizer.randomize(
            targetSlots: dinnerSlots(), current: [:], lockedSlots: [],
            candidates: [.dinner: candidates], excludedMealIDs: [], mode: .fillEmpty, using: &rngA
        )
        let resultB = MealRandomizer.randomize(
            targetSlots: dinnerSlots(), current: [:], lockedSlots: [],
            candidates: [.dinner: candidates], excludedMealIDs: [], mode: .fillEmpty, using: &rngB
        )

        #expect(resultA == resultB)
    }

    // MARK: - skippedCandidatesMessage

    @Test func skippedCandidatesMessageNamesASingleType() {
        let message = MealRandomizer.skippedCandidatesMessage(for: [.dinner])
        #expect(message == "Not enough dinners to choose from. Meals from last week are left out — add more dinners or pick one yourself.")
    }

    @Test func skippedCandidatesMessageJoinsMultipleTypes() {
        let message = MealRandomizer.skippedCandidatesMessage(for: [.breakfast, .dinner])
        #expect(message == "Not enough breakfasts and dinners to choose from. Meals from last week are left out — add more breakfasts and dinners or pick one yourself.")
    }
}
