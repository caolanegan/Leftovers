import SwiftUI
import UIKit

/// 56 pt rounded thumbnail for `MealRow`. Placeholder-only in M4: no meal has
/// `thumbnailData` yet since `MealEditorPhotoSection` arrives in M5, but this
/// already renders a real photo once one is set.
struct MealThumbnail: View {
    var thumbnailData: Data?
    var mealName: String
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel("Photo of \(mealName)")
            } else {
                Image(systemName: "fork.knife")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .clipped()
    }
}

#Preview {
    MealThumbnail(thumbnailData: nil, mealName: "Chicken fajitas")
}
