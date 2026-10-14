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
        code.map(Locale.init(identifier:)) ?? .autoupdatingCurrent
    }

    func set(_ newCode: String?, defaults: UserDefaults = .standard) {
        if let newCode {
            defaults.set(newCode, forKey: AppLocale.overrideKey)
            defaults.set([newCode], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: AppLocale.overrideKey)
            defaults.removeObject(forKey: "AppleLanguages")
        }
        AppLocale.setOverride(newCode)
        code = newCode
    }
}

/// Thread-safe access to the chosen language for code that isn't on the main
/// actor (error descriptions, models).
enum AppLocale {
    static let overrideKey = "roadivo.languageOverride"

    private static let storage = OverrideStorage(UserDefaults.standard.string(forKey: overrideKey))

    static var overrideCode: String? {
        storage.value
    }

    static func setOverride(_ code: String?) {
        storage.value = code
    }

    /// The locale lookups resolve in.
    static var current: Locale {
        overrideCode.map(Locale.init(identifier:)) ?? .current
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

/// A lock-guarded box, so the override can be read from any thread.
private final class OverrideStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: String?

    init(_ value: String?) {
        stored = value
    }

    var value: String? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}
