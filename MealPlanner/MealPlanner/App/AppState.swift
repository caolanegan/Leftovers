import Foundation

@Observable
final class AppState {
    enum AppTab: Hashable {
        case plan, meals, shopping, settings
    }

    var selectedTab: AppTab = .plan
    var selectedWeekID: String = WeekMath.weekID(for: .now, calendar: WeekMath.appCalendar)
}
