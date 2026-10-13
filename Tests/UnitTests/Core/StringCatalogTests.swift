import Foundation
import Testing

/// Every string the app shows must be translated into every shipped language,
/// with the same format specifiers as the English. Run Scripts/sync-strings.sh
/// after changing UI text, translate the new keys, then this goes green.
@Suite("String catalog")
struct StringCatalogTests {
    static let languages = ["es", "fr", "de", "it", "pt-BR", "ja", "ko", "zh-Hans", "zh-Hant", "hi"]

    /// The source catalog, read from the repo: the app bundle only holds the
    /// compiled per-language tables. The simulator shares the Mac's disk.
    private func catalog() throws -> CatalogFile {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent() // Core
            .deletingLastPathComponent() // UnitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // apps/Roadivo
            .appending(path: "Resources/Localizable.xcstrings")
        return try JSONDecoder().decode(CatalogFile.self, from: Data(contentsOf: url))
    }

    private func specifiers(_ text: String) -> [String] {
        let regex = /%(?:\d+\$)?(lld|@|d|%)/
        return text.matches(of: regex).map { String($0.output.1) }.sorted()
    }

    @Test("Every key is translated into all 10 languages")
    func complete() throws {
        let catalog = try catalog()
        var missing: [String] = []
        for (key, entry) in catalog.strings {
            for language in Self.languages where !(entry.localizations?[language]?.isTranslated ?? false) {
                missing.append("\(language): \(key)")
            }
        }
        #expect(missing.isEmpty, "Untranslated: \(missing.sorted().prefix(20))")
    }

    @Test("Translations keep the English format specifiers")
    func specifiersMatch() throws {
        let catalog = try catalog()
        for (key, entry) in catalog.strings {
            for (language, localization) in entry.localizations ?? [:] {
                for value in localization.allValues {
                    #expect(specifiers(value) == specifiers(key), "\(language): \(key) → \(value)")
                }
            }
        }
    }
}

private struct CatalogUnit: Decodable {
    let state: String
    let value: String
}

private struct CatalogLocalization: Decodable {
    struct Variations: Decodable {
        struct Variant: Decodable {
            let stringUnit: CatalogUnit
        }

        let plural: [String: Variant]?
    }

    let stringUnit: CatalogUnit?
    /// Plural forms ("1 channel" / "%lld channels").
    let variations: Variations?

    var allValues: [String] {
        if let stringUnit {
            return [stringUnit.value]
        }
        return variations?.plural?.values.map(\.stringUnit.value) ?? []
    }

    var isTranslated: Bool {
        if let stringUnit {
            return stringUnit.state == "translated"
        }
        guard let plural = variations?.plural, !plural.isEmpty else { return false }
        return plural.values.allSatisfy { $0.stringUnit.state == "translated" }
    }
}

private struct CatalogEntry: Decodable {
    let localizations: [String: CatalogLocalization]?
}

private struct CatalogFile: Decodable {
    let strings: [String: CatalogEntry]
}
