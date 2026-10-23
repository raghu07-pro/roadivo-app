import Foundation

/// Whether this build has Roadivo's CarPlay app: `ROADIVO_CARPLAY`, set to YES once Apple grants
/// the entitlement. Until then the app doesn't promise CarPlay anywhere.
enum CarPlayAvailability {
    static var hasExperimentalBrowser: Bool {
        #if DEBUG
            return (Bundle.main.object(forInfoDictionaryKey: "ROADIVO_CAR_BROWSER") as? String) == "YES"
        #else
            return false
        #endif
    }

    static var isEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "ROADIVO_CARPLAY") as? String) == "YES"
    }

    /// The CarPlay apps a build can be; an app is one (`ROADIVO_CARPLAY_APP`, DECISIONS 152).
    enum App: String {
        /// Roadivo's own window: the tabs as buttons, video while parked (navigation entitlement, no map).
        case window
        /// CarPlay's template tabs, with video only where the car offers it.
        case media
        /// The navigation map and guidance, kept for a later release (DECISIONS 147–149).
        case map
    }

    static var app: App {
        (Bundle.main.object(forInfoDictionaryKey: "ROADIVO_CARPLAY_APP") as? String).flatMap(App.init(rawValue:))
            ?? .media
    }

    /// `ROADIVO_CARPLAY_VIDEO`: signed with CarPlay Video instead of Audio, so the app shows only in cars that
    /// support video (DECISIONS 151). For the CarPlay trace.
    static var isVideoBuild: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "ROADIVO_CARPLAY_VIDEO") as? String) == "YES"
    }
}
