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
}
