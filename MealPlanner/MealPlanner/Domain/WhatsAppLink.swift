import Foundation

enum WhatsAppLink {
    enum Phone: Equatable { case empty, valid(digits: String), invalid }

    private static let strippedCharacters: Set<Character> = [" ", "-", "(", ")", "."]

    private static let unreservedCharacters: CharacterSet = {
        CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    }()

    static func normalizePhone(_ input: String) -> Phone {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        var digits = String(trimmed.filter { !strippedCharacters.contains($0) })
        if digits.hasPrefix("+") {
            digits.removeFirst()
        } else if digits.hasPrefix("00") {
            digits.removeFirst(2)
        }

        guard (8...15).contains(digits.count),
              digits.allSatisfy(\.isNumber),
              !digits.hasPrefix("0")
        else { return .invalid }

        return .valid(digits: digits)
    }

    static func url(text: String, phoneDigits: String?) -> URL? {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: unreservedCharacters) else {
            return nil
        }
        if let phoneDigits, !phoneDigits.isEmpty {
            return URL(string: "https://wa.me/\(phoneDigits)?text=\(encoded)")
        }
        return URL(string: "https://wa.me/?text=\(encoded)")
    }
}
