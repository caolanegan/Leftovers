import SwiftUI

/// §13.5 "Shopping": the progress card ("N of M ticked" / "X to go" above a
/// thicker bar), replaced by the "All done!" card once every item is
/// `.checked` (`.needsMore` doesn't count).
struct ShoppingProgressCard: View {
    let tickedCount: Int
    let totalCount: Int
    let isAllDone: Bool

    private var remaining: Int { max(totalCount - tickedCount, 0) }
    private var fraction: Double { totalCount > 0 ? Double(tickedCount) / Double(totalCount) : 0 }

    var body: some View {
        if isAllDone {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)
                Text("All done!")
                    .font(.title3.weight(.semibold))
                Text("Everything's ticked off. Enjoy your week of meals.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    (Text("\(tickedCount)").fontWeight(.bold) + Text(" of \(totalCount) ticked"))
                    Spacer()
                    Text("\(remaining) to go")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2))
                        Capsule().fill(Color.accentColor).frame(width: geometry.size.width * fraction)
                    }
                }
                .frame(height: 8)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(tickedCount) of \(totalCount) ticked, \(remaining) to go")
        }
    }
}

#Preview {
    List {
        Section { ShoppingProgressCard(tickedCount: 5, totalCount: 28, isAllDone: false) }
        Section { ShoppingProgressCard(tickedCount: 28, totalCount: 28, isAllDone: true) }
    }
}
