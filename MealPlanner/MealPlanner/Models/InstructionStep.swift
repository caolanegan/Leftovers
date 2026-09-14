import Foundation
import SwiftData

@Model
final class InstructionStep {
    var id: UUID = UUID()
    var text: String = ""
    var sortIndex: Int = 0
    var meal: Meal?

    init(text: String, sortIndex: Int) {
        self.text = text
        self.sortIndex = sortIndex
    }
}
