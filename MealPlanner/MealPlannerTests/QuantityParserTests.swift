import Testing
@testable import MealPlanner

@MainActor
struct QuantityParserTests {
    @Test(arguments: [
        ("", QuantityParser.Result.empty),
        ("   ", .empty),
        ("2", .value(2)),
        ("1.5", .value(1.5)),
        ("1,5", .value(1.5)),
        ("1,25", .value(1.25)),
        ("0,125", .value(0.125)),
        ("1,000", .value(1000)),
        ("12,000", .value(12000)),
        ("1/2", .value(0.5)),
        ("1 1/2", .value(1.5)),
        ("½", .value(0.5)),
        ("¼", .value(0.25)),
        ("¾", .value(0.75)),
        ("0", .invalid),
        ("-1", .invalid),
        ("abc", .invalid),
        ("1/0", .invalid),
        ("inf", .invalid),
        ("1e20", .invalid),
        ("0x10", .invalid),
        ("100001", .invalid),
    ])
    func parses(input: String, expected: QuantityParser.Result) {
        #expect(QuantityParser.parse(input) == expected)
    }
}
