import SwiftUI
import Testing
@testable import Leftovers

@MainActor
struct AppearancePreferenceTests {
    @Test(arguments: [
        (AppearancePreference.system, ColorScheme?.none),
        (AppearancePreference.light, .some(.light)),
        (AppearancePreference.dark, .some(.dark)),
    ])
    func mapsToColorScheme(preference: AppearancePreference, expected: ColorScheme?) {
        #expect(preference.colorScheme == expected)
    }

    @Test(arguments: ["system", "light", "dark"])
    func resolvesKnownRawValues(rawValue: String) {
        #expect(AppearancePreference.resolved(fromRawValue: rawValue).rawValue == rawValue)
    }

    @Test
    func unknownRawValueFallsBackToSystem() {
        #expect(AppearancePreference.resolved(fromRawValue: "sepia") == .system)
        #expect(AppearancePreference.resolved(fromRawValue: "") == .system)
    }
}
