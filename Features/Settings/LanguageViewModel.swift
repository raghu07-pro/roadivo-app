import Foundation
import Observation

struct LanguageOption: Identifiable, Hashable {
    let code: String

    var id: String {
        code
    }

    /// The language's own name ("Deutsch", "日本語").
    var name: String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forIdentifier: code)?.capitalized(with: locale) ?? code
    }

    var flag: String {
        let region = Locale(identifier: Locale.Language(identifier: code).maximalIdentifier).region?.identifier
        guard let region, region.count == 2 else { return "🌐" }
        return String(region.unicodeScalars.compactMap { UnicodeScalar(127_397 + $0.value) }.map(Character.init))
    }
}

/// The in-app language picker. Choosing a language applies at once
/// (`AppLanguage`); only languages the app ships are listed.
@Observable
@MainActor
final class LanguageViewModel {
    var query = ""

    let available: [LanguageOption]
    private let language: AppLanguage
    private let defaults: UserDefaults

    init(language: AppLanguage = .shared, bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        self.language = language
        self.defaults = defaults
        available = bundle.localizations
            .filter { $0 != "Base" }
            .map(LanguageOption.init(code:))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// `nil` follows the system language.
    var selected: String? {
        language.code
    }

    var filtered: [LanguageOption] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return available }
        return available
            .filter { $0.name.localizedStandardContains(needle) || $0.code.localizedStandardContains(needle) }
    }

    /// The current choice for the Settings row.
    var currentName: String {
        selected.map { LanguageOption(code: $0).name } ?? String(appLocalized: "Follow System")
    }

    /// `nil` follows the system language. Takes effect immediately.
    func choose(_ code: String?) {
        guard code != selected else { return }
        language.set(code, defaults: defaults)
    }
}
