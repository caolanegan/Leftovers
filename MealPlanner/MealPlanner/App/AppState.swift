import Foundation

@Observable
final class AppState {
    enum AppTab: Hashable {
        case plan, meals, shopping, settings
    }

    var selectedTab: AppTab = .plan
    var selectedWeekID: String = WeekMath.weekID(for: .now, calendar: WeekMath.appCalendar)
    /// §9.1's Shopping tab badge. Set by `ShoppingBadgeReporter` (in
    /// `RootTabView`) rather than read via a SwiftUI preference: iOS 18's
    /// `Tab` content hosts each tab in its own hierarchy, so a preference set
    /// inside the Shopping tab's content never reaches a `TabView`-level
    /// `.onPreferenceChange` — verified missing in the Simulator. Routing it
    /// through this `@Observable` instead crosses that boundary correctly.
    var shoppingBadgeCount: Int = 0
    /// Bumped whenever a randomise or shuffle succeeds, so every dice icon
    /// across the app (`RandomizeMenu`, day-header, row Shuffle, the picker's
    /// Shuffle button, the blank-week card) can bounce from one shared
    /// trigger (§13.5 "Randomising"), without each view needing its own.
    var diceBounceTick: Int = 0
}
