import Foundation

enum DurationFormatter {
    /// "45 min" below an hour; "1 hr", "1 hr 15 min", "2 hr 30 min" at or above.
    static func format(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        guard remainder > 0 else { return "\(hours) hr" }
        return "\(hours) hr \(remainder) min"
    }
}
