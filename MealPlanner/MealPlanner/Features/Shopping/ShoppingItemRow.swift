import SwiftUI

/// One row in `ShoppingListView` (§10.10).
struct ShoppingItemRow: View {
    let item: ShoppingListItem
    let status: CheckStatus
    let isReadOnly: Bool
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void

    private var isChecked: Bool {
        if case .checked = status { return true }
        return false
    }

    /// The caption's second line (§10.10): the meals it's used in, with
    /// "Added by you" appended to that same comma-joined list when there's a
    /// hand-added entry — e.g. usedIn `[]` + manual → "Added by you" alone;
    /// usedIn `["Fajitas"]` + manual → "Fajitas, Added by you".
    private var usageCaption: String? {
        var parts = item.usedIn
        if item.hasManualEntry { parts.append("Added by you") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    var body: some View {
        Group {
            if isReadOnly {
                rowContent
            } else {
                Button {
                    onToggle(!isChecked)
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    if item.hasManualEntry {
                        Button("Remove Added Item", role: .destructive, action: onRemove)
                        Button("Edit Added Item…", action: onEdit)
                            .tint(.accentColor)
                    }
                }
                .contextMenu {
                    if item.hasManualEntry {
                        Button("Edit Added Item…", action: onEdit)
                        Button("Remove Added Item", role: .destructive, action: onRemove)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                Text(item.displayName)
                    .foregroundStyle(isChecked ? .secondary : .primary)
                    .strikethrough(isChecked)
                Spacer()
                Text(QuantityFormatter.format(amounts: item.amounts))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if case .needsMore(let extras) = status {
                Text("Need \(QuantityFormatter.format(amounts: extras)) more")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let usageCaption {
                Text(usageCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private var iconName: String {
        switch status {
        case .unchecked: "circle"
        case .checked: "checkmark.circle.fill"
        case .needsMore: "exclamationmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .unchecked: .secondary
        case .checked: Color.accentColor
        case .needsMore: .orange
        }
    }

    private var accessibilityLabel: String {
        let amounts = QuantityFormatter.format(amounts: item.amounts)
        return amounts.isEmpty ? item.displayName : "\(item.displayName), \(amounts)"
    }

    private var accessibilityValue: String {
        switch status {
        case .unchecked: "not ticked"
        case .checked: "ticked"
        case .needsMore(let extras): "need \(QuantityFormatter.format(amounts: extras)) more"
        }
    }
}

#Preview {
    List {
        ShoppingItemRow(
            item: ShoppingListItem(key: "1", displayName: "Garlic", category: .produce, amounts: [.clove: 5], usedIn: ["Bolognese", "Veggie chilli"], hasManualEntry: false),
            status: .unchecked, isReadOnly: false, onToggle: { _ in }, onEdit: {}, onRemove: {}
        )
        ShoppingItemRow(
            item: ShoppingListItem(key: "2", displayName: "Chicken breast", category: .meatFish, amounts: [.g: 350], usedIn: ["Fajitas", "Caesar wrap"], hasManualEntry: false),
            status: .needsMore([.g: 150]), isReadOnly: false, onToggle: { _ in }, onEdit: {}, onRemove: {}
        )
        ShoppingItemRow(
            item: ShoppingListItem(key: "3", displayName: "Toilet roll", category: .household, amounts: [.pack: 1], usedIn: [], hasManualEntry: true),
            status: .unchecked, isReadOnly: false, onToggle: { _ in }, onEdit: {}, onRemove: {}
        )
    }
}
