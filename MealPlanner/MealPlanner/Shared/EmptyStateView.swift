import SwiftUI

/// The friendlier empty screens (§13.5): a symbol in a soft accent circle,
/// a title, body text, and up to two buttons (the first prominent). Used in
/// place of a plain `ContentUnavailableView` wherever §13.5 gives its own
/// copy and icon.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var primaryTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(Color.accentColor)
                .frame(width: 88, height: 88)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let primaryTitle, let primaryAction {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)
            }
            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        systemImage: "basket",
        title: "Your list is empty, for now",
        message: "Plan a few meals and everything you need lands here, sorted by aisle.",
        primaryTitle: "Plan Some Meals", primaryAction: {},
        secondaryTitle: "Add an Item", secondaryAction: {}
    )
}
