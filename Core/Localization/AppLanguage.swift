import Foundation
import Observation
import SwiftUI

/// The in-app language (Settings › Language), live: SwiftUI via the root locale, code via
/// `String(appLocalized:)` and `Text(app:)`; `AppleLanguages` updates system text next launch.
@Observable
@MainActor
final class AppLanguage {
    static let shared = AppLanguage()

    /// `nil` follows the iPhone's language.
    private(set) var code: String?

    /// Internal (not private) so tests can make their own.
    init() {
        code = AppLocale.overrideCode
    }

    /// The locale screens use: the chosen language, or the system's.
    var locale: Locale {
        code.map(Locale.init(identifier:)) ?? AppLocale.systemLocale ?? .autoupdatingCurrent
    }

    func set(_ newCode: String?, defaults: UserDefaults = .standard) {
        if let newCode {
            defaults.set(newCode, forKey: AppLocale.overrideKey)
            defaults.set([newCode], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: AppLocale.overrideKey)
            defaults.removeObject(forKey: "AppleLanguages")
            // With the override gone, this reads the iPhone's own list (or a -AppleLanguages argument).
            let preferred = defaults.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
            AppLocale.followSystem(preferring: preferred)
        }
        AppLocale.setOverride(newCode)
        code = newCode
    }
}

/// Thread-safe access to the chosen language for code that isn't on the main
/// actor (error descriptions, models).
enum AppLocale {
    static let overrideKey = "roadivo.languageOverride"

    private static let storage = LockedValue<String?>(UserDefaults.standard.string(forKey: overrideKey))
    /// Set by Follow System; until then `Locale.current` is already the iPhone's language.
    private static let system = LockedValue<Locale?>(nil)

    static var overrideCode: String? {
        storage.value
    }

    static func setOverride(_ code: String?) {
        storage.value = code
    }

    /// The iPhone's language as Follow System last resolved it, if it has.
    static var systemLocale: Locale? {
        system.value
    }

    /// `Locale.current` keeps a language chosen before launch until the next one, so Follow System
    /// resolves the iPhone's language itself.
    static func followSystem(preferring languages: [String], bundle: Bundle = .main) {
        system.value = resolveSystemLocale(preferences: languages, localizations: bundle.localizations)
    }

    /// The shipped language that `preferences` pick. `current` (with its region) when it already
    /// speaks that language; otherwise the language alone.
    static func resolveSystemLocale(
        preferences: [String],
        localizations: [String],
        current: Locale = .current
    ) -> Locale {
        let shipped = localizations.filter { $0 != "Base" }
        func match(_ languages: [String]) -> String? {
            Bundle.preferredLocalizations(from: shipped, forPreferences: languages).first
        }
        guard let language = match(preferences) else { return current }
        return match([current.language.maximalIdentifier]) == language ? current : Locale(identifier: language)
    }

    /// The locale lookups resolve in.
    static var current: Locale {
        overrideCode.map(Locale.init(identifier:)) ?? system.value ?? .current
    }
}

extension String {
    /// `String(localized:)` in the app's chosen language; takes a `LocalizedStringResource`, so
    /// catalog extraction and interpolation work as usual.
    init(appLocalized resource: LocalizedStringResource) {
        var resource = resource
        resource.locale = AppLocale.current
        self.init(localized: resource)
    }
}

extension AttributedString {
    init(appLocalized resource: LocalizedStringResource) {
        var resource = resource
        resource.locale = AppLocale.current
        self.init(localized: resource)
    }
}

extension Text {
    /// A stored `LocalizedStringResource` (onboarding pages, FAQ, plans) in
    /// the app's chosen language.
    init(app resource: LocalizedStringResource) {
        self.init(String(appLocalized: resource))
    }
}

/// A lock-guarded box, so the language can be read from any thread.
private final class LockedValue<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) {
        stored = value
    }

    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}
