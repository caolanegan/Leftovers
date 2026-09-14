import Foundation

enum QuantityParser {
    enum Result: Equatable { case empty, value(Double), invalid }

    static let maxValue: Double = 100_000

    private static let vulgarFractions: [Character: Double] = [
        "½": 0.5, "¼": 0.25, "¾": 0.75
    ]

    private static let allowedCharacters = CharacterSet(charactersIn: "0123456789.,/ ½¼¾")

    static func parse(_ text: String) -> Result {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        guard trimmed.unicodeScalars.allSatisfy(allowedCharacters.contains) else {
            return .invalid
        }

        let value: Double?
        if trimmed.count == 1, let fraction = vulgarFractions[trimmed[trimmed.startIndex]] {
            value = fraction
        } else {
            value = parseNumeric(trimmed)
        }

        guard let value, value.isFinite, value > 0, value <= maxValue else { return .invalid }
        return .value(value)
    }

    private static func parseNumeric(_ text: String) -> Double? {
        let parts = text.split(separator: " ", omittingEmptySubsequences: true)
        switch parts.count {
        case 1:
            return parseComponent(String(parts[0]))
        case 2:
            guard let whole = Double(normalizeSeparator(String(parts[0]))),
                  let fraction = parseFraction(String(parts[1]))
            else { return nil }
            return whole + fraction
        default:
            return nil
        }
    }

    private static func parseComponent(_ text: String) -> Double? {
        if text.contains("/") {
            return parseFraction(text)
        }
        return Double(normalizeSeparator(text))
    }

    private static func parseFraction(_ text: String) -> Double? {
        let parts = text.split(separator: "/")
        guard parts.count == 2,
              let numerator = Double(parts[0]),
              let denominator = Double(parts[1]),
              denominator != 0
        else { return nil }
        return numerator / denominator
    }

    /// A comma followed by exactly three digits to the end of the text is a thousands
    /// separator ("1,000" → "1000"); any other comma is a decimal separator ("1,5" → "1.5").
    private static func normalizeSeparator(_ text: String) -> String {
        if let commaIndex = text.firstIndex(of: ","),
           text.distance(from: commaIndex, to: text.endIndex) == 4 {
            let afterComma = text[text.index(after: commaIndex)...]
            if afterComma.allSatisfy(\.isNumber) {
                var thousands = text
                thousands.remove(at: commaIndex)
                return thousands
            }
        }
        return text.replacingOccurrences(of: ",", with: ".")
    }
}
