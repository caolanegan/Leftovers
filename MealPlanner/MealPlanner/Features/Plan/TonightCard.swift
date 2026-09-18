import SwiftUI

/// §13.5 "Tonight card": only on the current week, only when today's dinner
/// is planned. A read-only shortcut into the recipe — no swipe actions or
/// context menu.
struct TonightCard: View {
    let meal: Meal
    let isLeftovers: Bool
    let leftoverLabel: String?

    var body: some View {
        NavigationLink(value: AppRoute.meal(meal)) {
            HStack(spacing: 12) {
                MealThumbnail(thumbnailData: meal.thumbnailData, mealName: meal.name, size: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Label("TONIGHT", systemImage: "moon.stars")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MealType.dinner.tint)
                    Text(meal.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .accessibilityLabel("Tonight, \(meal.name)\(subtitle.map { ", \($0)" } ?? "")")
    }

    /// "30 min · 6 ingredients" (leaving out whichever part is zero, and the
    /// whole line if both are), or "Leftovers · Mon dinner" for a leftovers
    /// dinner (§13.5).
    private var subtitle: String? {
        if isLeftovers, let leftoverLabel {
            return "Leftovers · \(leftoverLabel)"
        }
        var parts: [String] = []
        if let minutes = meal.totalMinutes, minutes > 0 { parts.append(DurationFormatter.format(minutes: minutes)) }
        let count = meal.sortedIngredients.count
        if count > 0 { parts.append("\(count) ingredient\(count == 1 ? "" : "s")") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#Preview {
    List {
        Section {
            TonightCard(meal: Meal(name: "Chicken fajitas"), isLeftovers: false, leftoverLabel: nil)
        }
    }
}
