import Observation

/// App-wide navigation state: which tab, which sheet, which player surface.
@Observable
@MainActor
final class AppRouter {
    enum Tab: Hashable {
        case home
        case favorites
        case car
        case settings
    }

    enum PlayerSurface: String, Identifiable {
        case player
        case carMode

        var id: String {
            rawValue
        }
    }

    var selectedTab: Tab = .home
    var playerSurface: PlayerSurface?
    var isAddingSource = false
    /// Bumped when an App Store rating should be requested.
    private(set) var reviewRequests = 0
    /// The paywall over the tabs (Settings, the source limit, the Car tab).
    var paywall: PaywallReason?
    /// Bumped whenever the library changes, so every screen reloads.
    private(set) var libraryRevision = 0

    /// Off in UI-test runs: the system rating sheet would cover the screen.
    var asksForReviews = true

    func requestReview() {
        guard asksForReviews else { return }
        reviewRequests += 1
    }

    func libraryDidChange() {
        libraryRevision += 1
    }
}
