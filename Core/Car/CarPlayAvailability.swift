import Foundation

/// Whether this build has Roadivo's CarPlay app: `ROADIVO_CARPLAY`, set to YES once Apple grants
/// the entitlement. Until then the app doesn't promise CarPlay anywhere.
enum CarPlayAvailability {
    static var isEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "ROADIVO_CARPLAY") as? String) == "YES"
    }
}
