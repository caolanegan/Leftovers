import SwiftUI

/// One row in a `DaySection` (§10.1). Shuffle (swipe leading) and the
/// randomiser aren't built yet — that's M8.
struct MealSlotRow: View {
    let dayName: String   // full weekday, e.g. "Tuesday" — accessibility only
    let dayIndex: Int
    let mealType: MealType
    let plan: WeekPlan?
    let isReadOnly: Bool
    /// Precomputed by `DaySection` (it needs a service lookup for live weeks,
    /// unlike everything else this row reads straight off `plan`).
    let liveLeftoverSourceLabel: String?
    /// Whether "Mark as Leftovers" should be offered (cooked, with a candidate).
    let canMarkAsLeftovers: Bool
    let canLeftoversForTomorrowLunch: Bool
    let canLeftoversForTomorrowDinner: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    let onMarkAsLeftovers: () -> Void
    let onMarkAsCooked: () -> Void
    let onLeftoversForTomorrowLunch: () -> Void
    let onLeftoversForTomorrowDinner: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Wide enough for "Breakfast" (the longest meal type name) plus its icon
    /// at the current Dynamic Type size, so every row's name column lines up
    /// without wrapping (§13.2).
    @ScaledMetric(relativeTo: .body) private var mealTypeColumnWidth: CGFloat = 132

    private var slot: MealSlot? {
        (plan?.slots ?? []).first { $0.dayIndex == dayIndex && $0.mealType == mealType }
    }

    private var snapshot: ArchivedSlot? {
        guard isReadOnly, let slot, let json = slot.archivedSnapshotJSON else { return nil }
        return try? ArchiveCoding.decode(ArchivedSlot.self, from: json)
    }

    private var mealName: String? { snapshot?.mealName ?? slot?.meal?.name }
    private var isLeftovers: Bool { (snapshot?.leftoverOfSlotID ?? slot?.leftoverOfSlotID) != nil }
    private var leftoverLabel: String? { snapshot?.leftoverSourceLabel ?? liveLeftoverSourceLabel }
    private var isFilled: Bool { mealName != nil }

    private var recipeRoute: AppRoute? {
        guard let meal = slot?.meal else { return nil }
        return .meal(meal)
    }

    var body: some View {
        Group {
            if isReadOnly {
                readOnlyContent
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
                            if isLeftovers {
                                Button("Mark as Cooked", action: onMarkAsCooked)
                            } else if canMarkAsLeftovers {
                                Button("Mark as Leftovers", action: onMarkAsLeftovers)
                            }
                            if !isLeftovers, canLeftoversForTomorrowLunch {
                                Button("Leftovers for Tomorrow's Lunch", action: onLeftoversForTomorrowLunch)
                            }
                            if !isLeftovers, canLeftoversForTomorrowDinner {
                                Button("Leftovers for Tomorrow's Dinner", action: onLeftoversForTomorrowDinner)
                            }
                            Button("Remove", role: .destructive, action: onRemove)
                        }
                    }
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    /// Filled read-only rows push to `ArchivedSlotDetailView`; empty ones are
    /// a plain, non-tappable "—" with no chevron.
    @ViewBuilder
    private var readOnlyContent: some View {
        if isFilled, let slot {
            NavigationLink(value: AppRoute.archivedSlot(slot)) { rowContent }
        } else {
            rowContent
        }
    }

    /// A manual icon + text pairing rather than `Label`: `Label` can drop its
    /// title entirely (icon-only) when squeezed into a frame narrower than
    /// its ideal width, which a plain `HStack` never does.
    private var mealTypeLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: mealType.symbolName)
            Text(mealType.displayName)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var nameOrPlaceholder: some View {
        if let mealName {
            Text(mealName)
                .foregroundStyle(.primary)
        } else if isReadOnly {
            Text("—")
                .foregroundStyle(.secondary)
        } else {
            Text("Add \(mealType.displayName.lowercased())")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var trailingChevron: some View {
        if !isReadOnly {
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var leftoversCaption: some View {
        if isLeftovers, let leftoverLabel {
            Label("Leftovers · \(leftoverLabel)", systemImage: "arrow.uturn.backward")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if dynamicTypeSize.isAccessibilitySize {
                mealTypeLabel
                HStack {
                    nameOrPlaceholder
                    Spacer()
                    trailingChevron
                }
            } else {
                HStack {
                    mealTypeLabel
                        .frame(width: mealTypeColumnWidth, alignment: .leading)
                    nameOrPlaceholder
                    Spacer()
                    trailingChevron
                }
            }

            leftoversCaption
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
