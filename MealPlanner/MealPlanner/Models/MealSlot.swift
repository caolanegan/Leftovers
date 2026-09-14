import Foundation
import SwiftData

@Model
final class MealSlot {
    var id: UUID = UUID()
    var dayIndex: Int = 0                      // 0 = Monday … 6 = Sunday
    var mealTypeRaw: String = MealType.dinner.rawValue
    var leftoverOfSlotID: UUID? = nil          // set = this slot is leftovers of that cooked slot (§7.7)
    var archivedSnapshotJSON: String? = nil    // ArchivedSlot (§7.8), set on archive
    var weekPlan: WeekPlan?
    var meal: Meal?

    init(dayIndex: Int, mealType: MealType) {
        self.dayIndex = dayIndex
        self.mealTypeRaw = mealType.rawValue
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .dinner }
        set { mealTypeRaw = newValue.rawValue }
    }

    var isLeftovers: Bool { leftoverOfSlotID != nil }
}
