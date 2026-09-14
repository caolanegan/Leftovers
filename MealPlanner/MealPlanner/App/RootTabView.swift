import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            Tab("Plan", systemImage: "calendar", value: .plan) {
                NavigationStack {
                    PlaceholderScreen(title: "Plan")
                        .appRouteDestinations()
                }
            }
            Tab("Meals", systemImage: "fork.knife", value: .meals) {
                NavigationStack {
                    PlaceholderScreen(title: "Meals")
                        .appRouteDestinations()
                }
            }
            Tab("Shopping", systemImage: "cart", value: .shopping) {
                NavigationStack {
                    PlaceholderScreen(title: "Shopping")
                        .appRouteDestinations()
                }
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsView()
                        .appRouteDestinations()
                }
            }
        }
    }
}

/// Stands in for a tab's root screen until the milestone that builds it.
private struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        Text("\(title) is coming soon.")
            .foregroundStyle(.secondary)
            .navigationTitle(title)
    }
}

#Preview {
    RootTabView()
        .environment(AppState())
        .modelContainer(PreviewContainer.shared)
}
