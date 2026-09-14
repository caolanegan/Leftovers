import SwiftUI
import SwiftData

/// Temporary Settings screen (SPEC §16 M3): only the Library link exists so
/// far. Reminder, WhatsApp and About sections arrive in M11 (§10.12).
struct SettingsView: View {
    var body: some View {
        Form {
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
