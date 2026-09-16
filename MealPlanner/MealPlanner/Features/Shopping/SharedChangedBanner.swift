import SwiftUI

/// §10.10: shown when `lastSharedSignature` no longer matches the current list.
struct SharedChangedBanner: View {
    let onShareAgain: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Label("Your list has changed since you shared it.", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Share Again", action: onShareAgain)
                .font(.footnote)
        }
    }
}

#Preview {
    List {
        Section {
            SharedChangedBanner(onShareAgain: {})
        }
    }
}
