import Foundation

/// Product-level copy shared by several screens.
enum Brand {
    static let tagline: LocalizedStringResource = "Let the Journey Play."

    /// Sent with Settings › Share Roadivo; reads well with or without a link.
    static let shareMessage: LocalizedStringResource =
        "I watch my playlists and videos on the road with Roadivo. Find it on the App Store."
}

/// Legal links. Terms are Apple's standard EULA (`TERMS_URL`); the privacy
/// policy is shown in the app (`PrivacyPolicyView`).
enum LegalLinks {
    static var terms: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "TERMS_URL") as? String).flatMap(URL.init(string:))
    }
}

/// Roadivo's App Store listing, from `APP_STORE_ID` (Config/Shared.xcconfig).
/// Both links are `nil` until the ID is set.
struct AppStoreLinks: Equatable {
    /// The listing, for sharing.
    let page: URL?
    /// Apple's deep link straight to "Write a Review": the recommended target
    /// for a permanent rating button (the system prompt is for natural
    /// moments only, and iOS may not show it).
    let writeReview: URL?

    init(appStoreID: String?) {
        let id = appStoreID?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !id.isEmpty, id.allSatisfy(\.isASCIIDigit) else {
            page = nil
            writeReview = nil
            return
        }
        page = URL(string: "https://apps.apple.com/app/id\(id)")
        writeReview = URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")
    }

    static var current: AppStoreLinks {
        AppStoreLinks(appStoreID: Bundle.main.object(forInfoDictionaryKey: "APP_STORE_ID") as? String)
    }
}

private extension Character {
    var isASCIIDigit: Bool {
        isASCII && isNumber
    }
}
