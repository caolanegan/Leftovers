import Foundation

enum NameNormalizer {
    static func key(_ name: String) -> String {
        clean(name)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
    }

    static func clean(_ name: String) -> String {
        name
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
