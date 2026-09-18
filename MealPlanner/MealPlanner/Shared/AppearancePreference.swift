import SwiftUI

/// §10.12 item 3. Stored as a plain `String` in `@AppStorage("appearance")`,
/// not a `@Model` property, so no schema version is needed.
enum AppearancePreference: String, CaseIterable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// A raw value that doesn't match a known case (e.g. left over from a
    /// future app version) falls back to System rather than failing to load.
    static func resolved(fromRawValue rawValue: String) -> AppearancePreference {
        AppearancePreference(rawValue: rawValue) ?? .system
    }
}
