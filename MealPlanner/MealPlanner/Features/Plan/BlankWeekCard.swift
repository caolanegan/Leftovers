import SwiftUI

/// §13.5 "Blank week card": shown above Monday on an editable week with
/// nothing planned at all. Disappears as soon as anything is planned.
struct BlankWeekCard: View {
    let onRandomizeWeek: () -> Void
    let onPickAMeal: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "dice")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                .symbolEffect(.bounce, value: reduceMotion ? 0 : appState.diceBounceTick)

            VStack(spacing: 4) {
                Text("A blank week")
                    .font(.headline)
                Text("Nothing planned yet. Roll the dice for a surprise week, or pick your first meal.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Button("Randomise Week", action: onRandomizeWeek)
                    .buttonStyle(.borderedProminent)
                Button("Pick a Meal", action: onPickAMeal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    List {
        Section {
            BlankWeekCard(onRandomizeWeek: {}, onPickAMeal: {})
        }
    }
    .environment(AppState())
}
