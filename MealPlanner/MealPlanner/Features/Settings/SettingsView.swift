import SwiftUI
import SwiftData

/// Temporary Settings screen (SPEC §16 M3). Reminder and About sections
/// arrive in M11 (§10.12).
struct SettingsView: View {
    var body: some View {
        Form {
            WhatsAppContactSection()
            Section("Library") {
                NavigationLink("Ingredients", value: AppRoute.ingredientLibrary)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .appRouteDestinations()
    }
    .modelContainer(PreviewContainer.shared)
}
