import Testing
@testable import Leftovers

@MainActor
struct DurationFormatterTests {
    @Test(arguments: [
        (5, "5 min"),
        (45, "45 min"),
        (60, "1 hr"),
        (75, "1 hr 15 min"),
        (90, "1 hr 30 min"),
        (120, "2 hr"),
        (150, "2 hr 30 min"),
        (180, "3 hr"),
    ])
    func formatsMinutes(minutes: Int, expected: String) {
        #expect(DurationFormatter.format(minutes: minutes) == expected)
    }
}
