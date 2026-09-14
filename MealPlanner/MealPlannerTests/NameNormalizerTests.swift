import Testing
@testable import MealPlanner

@MainActor
struct NameNormalizerTests {
    @Test func keyStripsDiacriticsCaseAndWhitespace() {
        #expect(NameNormalizer.key("  Crème  Fraîche ") == "creme fraiche")
    }

    @Test func cleanTrimsAndCollapsesWhitespaceButKeepsCase() {
        #expect(NameNormalizer.clean("  Red   onion ") == "Red onion")
    }
}
