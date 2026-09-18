import SwiftUI

/// §13.5 "Shopping": a small tinted tile with the aisle's symbol, the aisle
/// name, and the item count on the trailing side.
struct AisleHeader: View {
    let category: ShoppingCategory
    let count: Int

    var body: some View {
        HStack {
            Image(systemName: category.symbolName)
                .font(.caption)
                .foregroundStyle(category.tint)
                .frame(width: 22, height: 22)
                .background(category.tint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(category.displayName)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        Section {
            Text("Garlic")
        } header: {
            AisleHeader(category: .produce, count: 4)
        }
    }
}
