import SwiftUI

/// One row in a `DaySection` (§10.1).
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
    let onShuffle: () -> Void
    let onMarkAsLeftovers: () -> Void
    let onMarkAsCooked: () -> Void
    let onLeftoversForTomorrowLunch: () -> Void
    let onLeftoversForTomorrowDinner: () -> Void

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
                    .swipeActions(edge: .leading) {
                        Button("Shuffle", systemImage: "dice", action: onShuffle)
                            .tint(.accentColor)
                    }
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
                            Button("Shuffle", systemImage: "dice", action: onShuffle)
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

    /// The meal type caption (bold, in its tint, with its symbol) that sits
    /// above the meal name (§13.5 "Rows").
    private var mealTypeLabel: some View {
        Label(mealType.displayName, systemImage: mealType.symbolName)
            .font(.caption.weight(.bold))
            .foregroundStyle(mealType.tint)
    }

    @ViewBuilder
    private var nameOrPlaceholder: some View {
        if let mealName {
            Text(mealName)
                .foregroundStyle(.primary)
                .contentTransition(.opacity)
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

    /// A 32 pt photo, or (empty, editable slot only) a dashed rounded square
    /// with a `plus` in the meal type's tint (§13.5 "Rows"). Read-only rows
    /// never read `slot.meal`'s live photo (§6.7) — a filled archived row
    /// falls back to `MealThumbnail`'s own placeholder icon.
    @ViewBuilder
    private var leadingThumbnail: some View {
        if isFilled {
            MealThumbnail(thumbnailData: isReadOnly ? nil : slot?.meal?.thumbnailData, mealName: mealName ?? "", size: 32)
        } else if !isReadOnly {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(mealType.tint, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(mealType.tint)
                }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            leadingThumbnail
            VStack(alignment: .leading, spacing: 2) {
                mealTypeLabel
                nameOrPlaceholder
                leftoversCaption
            }
            Spacer()
            trailingChevron
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
