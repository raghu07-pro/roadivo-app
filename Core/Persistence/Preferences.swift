import Foundation
import Observation

/// Small user settings kept in UserDefaults (nothing sensitive).
@Observable
@MainActor
final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    /// The one-time "Buy a plan" screen after onboarding has been closed.
    var hasSeenIntroPaywall: Bool {
        didSet { defaults.set(hasSeenIntroPaywall, forKey: Keys.introPaywall) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        hasSeenIntroPaywall = defaults.bool(forKey: Keys.introPaywall)
    }

    /// Identifies this install to media servers (their "devices" list). Not
    /// personal data and not a credential.
    var deviceID: String {
        if let existing = defaults.string(forKey: Keys.deviceID) {
            return existing
        }
        let created = UUID().uuidString
        defaults.set(created, forKey: Keys.deviceID)
        return created
    }

    /// How many videos the user has opened, for the review prompt.
    var videosOpened: Int {
        get { defaults.integer(forKey: Keys.videosOpened) }
        set { defaults.set(newValue, forKey: Keys.videosOpened) }
    }

    private enum Keys {
        static let videosOpened = "roadivo.videosOpened"
        static let onboarding = "roadivo.hasCompletedOnboarding"
        static let introPaywall = "roadivo.hasSeenIntroPaywall"
        static let deviceID = "roadivo.deviceID"
    }
}
