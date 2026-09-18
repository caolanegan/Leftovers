import SwiftUI
import SwiftData

@main
struct MealPlannerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("appearance") private var appearanceRawValue = AppearancePreference.system.rawValue
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainerFactory.make()
        } catch {
            fatalError("Could not create the SwiftData model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(appDelegate.appState)
                .preferredColorScheme(AppearancePreference.resolved(fromRawValue: appearanceRawValue).colorScheme)
        }
        .modelContainer(modelContainer)
    }
}
