import SwiftUI

/// One row in a `DaySection` (§10.1). Shuffle (swipe leading, M8) and
/// "Mark as Leftovers"/"Leftovers for Tomorrow's …" (context menu, M7) aren't
/// built yet — M6 only has "View Recipe" and "Remove".
struct MealSlotRow: View {
    let dayName: String   // full weekday, e.g. "Tuesday" — accessibility only
    let dayIndex: Int
    let mealType: MealType
    let plan: WeekPlan?
    let isReadOnly: Bool
    let onTap: () -> Void
    let onRemove: () -> Void

    private var slot: MealSlot? {
        (plan?.slots ?? []).first { $0.dayIndex == dayIndex && $0.mealType == mealType }
    }

    private var snapshot: ArchivedSlot? {
        guard isReadOnly, let slot, let json = slot.archivedSnapshotJSON else { return nil }
        return try? ArchiveCoding.decode(ArchivedSlot.self, from: json)
    }

    private var mealName: String? { snapshot?.mealName ?? slot?.meal?.name }
    private var isLeftovers: Bool { (snapshot?.leftoverOfSlotID ?? slot?.leftoverOfSlotID) != nil }
    private var leftoverLabel: String? { snapshot?.leftoverSourceLabel }
    private var isFilled: Bool { mealName != nil }

    /// `nil` (a non-tappable row) unless this is a filled, read-only slot.
    private var archivedRoute: AppRoute? {
        guard isReadOnly, isFilled, let slot else { return nil }
        return .archivedSlot(slot)
    }

    private var recipeRoute: AppRoute? {
        guard let meal = slot?.meal else { return nil }
        return .meal(meal)
    }

    var body: some View {
        Group {
            if isReadOnly {
                NavigationLink(value: archivedRoute) { rowContent }
            } else {
                Button(action: onTap) { rowContent }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        if isFilled {
                            Button("Remove", role: .destructive, action: onRemove)
                        }
                    }
                    .contextMenu {
                        if isFilled {
                            NavigationLink(value: recipeRoute) {
                                Label("View Recipe", systemImage: "fork.knife")
                            }
                            Button("Remove", role: .destructive, action: onRemove)
                        }
                    }
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Label(mealType.displayName, systemImage: mealType.symbolName)
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .leading)

                if let mealName {
                    Text(mealName)
                        .foregroundStyle(.primary)
                } else {
                    Text("Add \(mealType.displayName.lowercased())")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isReadOnly {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if isLeftovers, let leftoverLabel {
                Label("Leftovers · \(leftoverLabel)", systemImage: "arrow.uturn.backward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private var accessibilityLabel: String {
        var parts = ["\(dayName) \(mealType.displayName.lowercased())"]
        if let mealName {
            parts.append(mealName)
        }
        if isLeftovers, let leftoverLabel {
            parts.append("leftovers from \(leftoverLabel.lowercased())")
        }
        return parts.joined(separator: ", ")
    }
}
