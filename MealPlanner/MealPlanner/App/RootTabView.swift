import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "RootTabView")

struct RootTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var mealsPath = NavigationPath()

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            Tab("Plan", systemImage: "calendar", value: .plan) {
                NavigationStack {
                    WeekPlanView()
                        .appRouteDestinations()
                }
            }
            Tab("Meals", systemImage: "fork.knife", value: .meals) {
                NavigationStack(path: $mealsPath) {
                    MealLibraryView()
                        .appRouteDestinations(path: $mealsPath)
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
        .task { archiveEndedWeeks() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { archiveEndedWeeks() }
        }
    }

    /// §8.1: called at launch and whenever `scenePhase` becomes `.active`, so
    /// an app left open past Sunday midnight archives before the next change.
    private func archiveEndedWeeks() {
        do {
            try ArchiveService(context: modelContext).archiveEndedWeeks()
        } catch {
            logger.error("Failed to archive ended weeks: \(error, privacy: .public)")
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
