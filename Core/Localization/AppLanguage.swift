import Foundation
import Observation
import SwiftUI

/// The language Roadivo shows, switchable live from Settings › Language.
///
/// iOS only applies `AppleLanguages` at the next launch, and
/// `String(localized:)` always uses the launch language. So the app routes
/// every lookup through this choice instead:
/// - SwiftUI text (`Text("…")`, labels, titles) via `.environment(\.locale)` at the root;
/// - strings built in code via `String(appLocalized:)`;
/// - stored resources via `Text(app:)`.
/// The root view is rebuilt when the choice changes, so every screen redraws
/// in the new language at once. `AppleLanguages` is still written, so system
/// texts (permission prompts, the home-screen name) follow on the next launch.
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
    /// `String(localized:)` in the app's chosen language. Takes a
    /// `LocalizedStringResource`, so string-catalog extraction and
    /// interpolation work exactly as with `String(localized:)`.
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
