import Foundation

/// Product-level copy shared by several screens.
enum Brand {
    static let tagline: LocalizedStringResource = "Let the Journey Play."
}

/// Legal links. Terms are Apple's standard EULA (`TERMS_URL`); the privacy
/// policy is shown in the app (`PrivacyPolicyView`).
enum LegalLinks {
    static var terms: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "TERMS_URL") as? String).flatMap(URL.init(string:))
    }
}
