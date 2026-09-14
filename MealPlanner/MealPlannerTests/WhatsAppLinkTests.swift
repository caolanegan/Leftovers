import Testing
import Foundation
@testable import MealPlanner

@MainActor
struct WhatsAppLinkTests {
    @Test func normalizesAPlusPrefixedInternationalNumber() {
        #expect(WhatsAppLink.normalizePhone("+44 7700 900123") == .valid(digits: "447700900123"))
    }

    @Test func normalizesADoubleZeroPrefixedInternationalNumber() {
        #expect(WhatsAppLink.normalizePhone("0044 (7700) 900-123") == .valid(digits: "447700900123"))
    }

    @Test func rejectsANumberWithoutACountryCode() {
        #expect(WhatsAppLink.normalizePhone("07700 900123") == .invalid)
    }

    @Test func emptyInputIsEmpty() {
        #expect(WhatsAppLink.normalizePhone("") == .empty)
    }

    @Test func buildsAChatPickerURLWithoutAPhoneNumber() {
        let url = WhatsAppLink.url(text: "Hi & bye\n*List*", phoneDigits: nil)
        #expect(url?.absoluteString == "https://wa.me/?text=Hi%20%26%20bye%0A%2AList%2A")
    }

    @Test func buildsADirectChatURLWithAPhoneNumber() {
        let url = WhatsAppLink.url(text: "•", phoneDigits: "447700900123")
        #expect(url?.absoluteString == "https://wa.me/447700900123?text=%E2%80%A2")
    }
}
