import Foundation

/// Whether this build has Roadivo's CarPlay app: `ROADIVO_CARPLAY`, set to YES once Apple grants
/// the entitlement. Until then the app doesn't promise CarPlay anywhere.
enum CarPlayAvailability {
    static var isEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "ROADIVO_CARPLAY") as? String) == "YES"
    }

    /// `ROADIVO_CARPLAY_NAVIGATION`: the car shows Roadivo's map and guidance instead of its media lists
    /// (DECISIONS 147). Off since DECISIONS 148, so the car shows the media tabs.
    static var isNavigation: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "ROADIVO_CARPLAY_NAVIGATION") as? String) == "YES"
    }
}
