import SwiftUI

struct MealRow: View {
    let meal: Meal

    var body: some View {
        HStack(spacing: 12) {
            MealThumbnail(thumbnailData: meal.thumbnailData, mealName: meal.name)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(meal.name)
                    if meal.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var subtitle: String {
        var parts: [String] = []
        let types = meal.mealTypes.sorted().map(\.displayName)
        if !types.isEmpty { parts.append(types.joined(separator: ", ")) }
        let count = meal.sortedIngredients.count
        parts.append("\(count) ingredient\(count == 1 ? "" : "s")")
        if let minutes = meal.totalMinutes { parts.append("\(minutes) min") }
        return parts.joined(separator: " · ")
    }

    private var accessibilityLabelText: String {
        var label = meal.name
        if meal.isFavorite { label += ", Favourite" }
        label += ", " + subtitle
        return label
    }
}

#Preview {
    List {
        MealRow(meal: Meal(name: "Chicken fajitas"))
    }
}
