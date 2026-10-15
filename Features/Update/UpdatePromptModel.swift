import Foundation
import Observation

/// Decides when "New Version Available" shows: a newer App Store version, checked at most once a
/// day, and never again for a version the user closed.
@Observable
@MainActor
final class UpdatePromptModel {
    private(set) var release: AppRelease?

    private let checker: AppUpdateChecking?
    private let defaults: UserDefaults
    private let currentVersion: String
    private let now: () -> Date

    init(
        checker: AppUpdateChecking?,
        defaults: UserDefaults = .standard,
        currentVersion: String = AppVersion.current,
        now: @escaping () -> Date = Date.init
    ) {
        self.checker = checker
        self.defaults = defaults
        self.currentVersion = currentVersion
        self.now = now
    }

    func check() async {
        guard let checker, release == nil else { return }
        if let last = defaults.object(forKey: Keys.lastCheck) as? Date, now().timeIntervalSince(last) < 86400 {
            return
        }
        defaults.set(now(), forKey: Keys.lastCheck)
        do {
            guard let latest = try await checker.latestRelease(),
                  AppVersion.isNewer(latest.version, than: currentVersion),
                  latest.version != defaults.string(forKey: Keys.closedVersion) else { return }
            release = latest
        } catch {
            // Offline or no answer: nothing to show, and it asks again tomorrow.
        }
    }

    /// ✕: this version isn't offered again.
    func close() {
        if let release {
            defaults.set(release.version, forKey: Keys.closedVersion)
        }
        release = nil
    }

    /// Update Now: the App Store opens; if the user doesn't update, it asks again another day.
    func openStore() -> URL? {
        defer { release = nil }
        return release?.storeURL
    }

    private enum Keys {
        static let lastCheck = "roadivo.update.lastCheck"
        static let closedVersion = "roadivo.update.closedVersion"
    }
}
