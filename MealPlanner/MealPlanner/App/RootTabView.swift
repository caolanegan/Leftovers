import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "RootTabView")

struct RootTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var mealsPath = NavigationPath()

    @AppStorage("reminder.enabled") private var reminderEnabled = false
    @AppStorage("reminder.weekday") private var reminderWeekday = 1
    @AppStorage("reminder.minutes") private var reminderMinutes = 1080

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
                    ShoppingListView()
                        .appRouteDestinations()
                }
            }
            .badge(appState.shoppingBadgeCount)
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsView()
                        .appRouteDestinations()
                }
            }
        }
        // Not inside the Shopping tab's own content: `Tab` builds its content
        // lazily, so the badge would stay 0 until the user opens that tab at
        // least once. A `.background` on the `TabView` itself is always built.
        .background(ShoppingBadgeReporter(weekID: appState.selectedWeekID).id(appState.selectedWeekID))
        // §13.5: applied once, at the root, so every tab, sheet, alert and
        // confirmation dialog presented from within this hierarchy inherits it.
        .fontDesign(.rounded)
        .task { onBecomeActive() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { onBecomeActive() }
        }
    }

    /// §9.2: at launch and whenever `scenePhase` becomes `.active`, archive
    /// ended weeks (so an app left open past Sunday midnight archives before
    /// the next change), then re-sync the reminder (§11.3 "App becomes
    /// active").
    private func onBecomeActive() {
        archiveEndedWeeks()
        Task { await resyncReminder() }
    }

    private func archiveEndedWeeks() {
        do {
            try ArchiveService(context: modelContext).archiveEndedWeeks()
        } catch {
            logger.error("Failed to archive ended weeks: \(error, privacy: .public)")
        }
    }

    /// If the reminder is enabled and still authorised, reschedule it (in
    /// case the system dropped the pending request). If permission has been
    /// revoked, leave the stored toggle alone — `ReminderSettingsView`'s
    /// footer shows the warning when the user looks at its page.
    private func resyncReminder() async {
        guard reminderEnabled else { return }
        let scheduler = NotificationScheduler()
        switch await scheduler.authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            do {
                try await scheduler.scheduleWeeklyReminder(
                    weekday: reminderWeekday, hour: reminderMinutes / 60, minute: reminderMinutes % 60
                )
            } catch {
                logger.error("Failed to resync reminder: \(error, privacy: .public)")
            }
        default:
            break
        }
    }
}

/// Invisible: computes the Shopping tab's badge (§9.1 — `.unchecked` +
/// `.needsMore` items, only for a non-archived week) and writes it to
/// `AppState`, so the count stays correct even while that tab has never been
/// opened. `@Query` (not read directly — declaring it is enough) keeps this
/// live as recipes and ingredients change elsewhere, same reasoning as
/// `ShoppingListView`.
private struct ShoppingBadgeReporter: View {
    let weekID: String

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var plans: [WeekPlan]
    @Query private var meals: [Meal]
    @Query private var ingredients: [Ingredient]

    init(weekID: String) {
        self.weekID = weekID
        let id = weekID
        _plans = Query(filter: #Predicate<WeekPlan> { $0.weekID == id })
    }

    private var count: Int {
        guard let plan = plans.first, !plan.isArchived else { return 0 }
        let service = WeekPlanService(context: modelContext)
        let sections = ShoppingListBuilder.build(from: service.shoppingLines(for: plan))
        let statuses = service.statuses(for: plan, sections: sections)
        return statuses.values.filter {
            if case .checked = $0 { return false }
            return true
        }.count
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task(id: count) { appState.shoppingBadgeCount = count }
    }
}

#Preview {
    RootTabView()
        .environment(AppState())
        .modelContainer(PreviewContainer.shared)
}
