import SwiftUI

/// Sits in `WeekPlanView`'s `safeAreaInset(edge: .top)` (§10.1). Chevrons move
/// ±1 week; tapping the title jumps back to this week.
struct WeekNavigator: View {
    let title: String
    let subtitle: String
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous week")

                Spacer()

                Button(action: onToday) {
                    Text(title)
                        .font(.headline)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next week")
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

#Preview {
    WeekNavigator(
        title: "This week · 14–20 Sep",
        subtitle: "12 of 21 meals planned",
        onPrevious: {},
        onNext: {},
        onToday: {}
    )
}
