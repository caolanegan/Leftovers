import SwiftUI

/// The toolbar 🎲 menu (§10.1), for the whole week or one meal type across
/// all 7 days. Day- and slot-level randomising live in `DaySection` and
/// `MealSlotRow`/`MealPickerSheet` respectively.
enum RandomizeScope {
    case wholeWeek
    case mealType(MealType)
}

struct RandomizeMenu: View {
    let onSelect: (RandomizeScope) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Menu {
            Button("Randomise Whole Week") { onSelect(.wholeWeek) }
            ForEach(MealType.allCases.sorted()) { type in
                Button("Randomise \(type.pluralName)") { onSelect(.mealType(type)) }
            }
        } label: {
            Image(systemName: "dice")
                .symbolEffect(.bounce, value: reduceMotion ? 0 : appState.diceBounceTick)
        }
        .accessibilityLabel("Randomise")
    }
}

#Preview {
    RandomizeMenu(onSelect: { _ in })
        .environment(AppState())
}
