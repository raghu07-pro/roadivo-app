import Foundation

/// A site on the Browser's start page, like CarTV's grid (owner, 2026-10-19). Tapping it opens the website
/// in the Browser, never its app. Its icon comes from the site at run time, as Safari's Favorites do, so
/// no other company's logo ships inside Roadivo (App Review 5.2.1; DECISIONS 118).
struct BrowserSite: Identifiable, Hashable, Sendable {
    let name: String
    let url: URL

    var id: String {
        name
    }

    /// The site's own icon, through Google's icon service, which sees only the site's name.
    var iconURL: URL? {
        guard let host = url.host() else { return nil }
        var icon = URLComponents(string: "https://www.google.com/s2/favicons")
        icon?.queryItems = [URLQueryItem(name: "domain", value: host), URLQueryItem(name: "sz", value: "128")]
        return icon?.url
    }

    static let all: [BrowserSite] = [
        ("Google", "https://www.google.com"),
        ("iQIYI International", "https://www.iq.com"),
        ("YouTube", "https://m.youtube.com"),
        ("TikTok", "https://www.tiktok.com"),
        ("Twitch", "https://m.twitch.tv"),
        ("Vimeo", "https://vimeo.com"),
        ("Dailymotion", "https://www.dailymotion.com"),
        ("Instagram", "https://www.instagram.com"),
        ("HBO Max", "https://www.hbomax.com"),
        ("Peacock", "https://www.peacocktv.com"),
        ("Paramount+", "https://www.paramountplus.com"),
        ("Crunchyroll", "https://www.crunchyroll.com"),
        ("Rakuten Viki", "https://www.viki.com"),
        ("Tubi", "https://tubitv.com"),
        ("Pluto TV", "https://pluto.tv"),
        ("Plex", "https://watch.plex.tv")
    ].compactMap { name, address in
        URL(string: address).map { BrowserSite(name: name, url: $0) }
    }
}
