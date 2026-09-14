import Foundation

enum QuantityParser {
    enum Result: Equatable { case empty, value(Double), invalid }

    private static let vulgarFractions: [Character: Double] = [
        "½": 0.5, "¼": 0.25, "¾": 0.75
    ]

    static func parse(_ text: String) -> Result {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        let value: Double?
        if trimmed.count == 1, let fraction = vulgarFractions[trimmed[trimmed.startIndex]] {
            value = fraction
        } else {
            value = parseNumeric(trimmed)
        }

        guard let value, value > 0 else { return .invalid }
        return .value(value)
    }

    private static func parseNumeric(_ text: String) -> Double? {
        let parts = text.split(separator: " ", omittingEmptySubsequences: true)
        switch parts.count {
        case 1:
            return parseComponent(String(parts[0]))
        case 2:
            guard let whole = Double(parts[0].replacingOccurrences(of: ",", with: ".")),
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
        return Double(text.replacingOccurrences(of: ",", with: "."))
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
}
