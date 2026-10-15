import Foundation

/// The server types "Or connect a media server" offers. Plex signs in with a code at plex.tv/link;
/// the others take an address and a login.
enum MediaServerKind: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case jellyfin
    case emby
    case xtream
    case plex

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .jellyfin: "Jellyfin"
        case .emby: "Emby"
        case .xtream: "Xtream"
        case .plex: "Plex"
        }
    }

    /// What the card under "Or connect a media server" says.
    var subtitle: LocalizedStringResource {
        switch self {
        case .jellyfin, .emby: "Your own server"
        case .xtream: "IPTV provider login"
        case .plex: "Sign in with a code"
        }
    }

    var symbol: String {
        switch self {
        case .jellyfin: "triangle.fill"
        case .emby: "play.rectangle.fill"
        case .xtream: "play.tv.fill"
        case .plex: "chevron.right"
        }
    }

    var addressPlaceholder: String {
        switch self {
        case .jellyfin, .emby: "http://192.168.1.10:8096"
        case .xtream: "http://provider.example.com:8080"
        case .plex: ""
        }
    }
}

/// Turns what a user types ("192.168.1.10:8096", "tv.example.com/web/#/home") into a base URL.
/// No scheme means https for media servers (no cleartext password), http on a LAN or for Xtream.
enum ServerAddress {
    /// Xtream panels are nearly all plain http, and their login travels in the link either way.
    static func normalize(_ raw: String, preferringHTTPS: Bool = true) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(" ") else { return nil }
        if let fragment = text.firstIndex(of: "#") {
            text = String(text[..<fragment])
        }
        let lowercased = text.lowercased()
        if !lowercased.hasPrefix("http://"), !lowercased.hasPrefix("https://") {
            text = (preferringHTTPS && !isOnLocalNetwork(text) ? "https://" : "http://") + text
        }
        guard var components = URLComponents(string: text), components.host?.isEmpty == false else { return nil }
        // A link copied from Jellyfin's or Emby's web app: the server is everything before /web.
        let segments = components.path.split(separator: "/")
        if let web = segments.firstIndex(where: { $0.lowercased() == "web" }) {
            components.path = segments[..<web].map { "/" + $0 }.joined()
            components.query = nil
        }
        guard var normalized = components.string else { return nil }
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        guard let url = URL(string: normalized), url.host() != nil else { return nil }
        return url
    }

    /// IP addresses, localhost, .local and single-label names (a NAS on home Wi-Fi) rarely have a
    /// certificate, so they keep http.
    private static func isOnLocalNetwork(_ address: String) -> Bool {
        guard let host = URLComponents(string: "http://" + address)?.host?.lowercased(), !host.isEmpty else {
            return false
        }
        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        let isIPv4 = octets.count == 4 && octets.allSatisfy { UInt8($0) != nil }
        let isIPv6 = host.contains(":")
        return isIPv4 || isIPv6 || host == "localhost" || host.hasSuffix(".local") || !host.contains(".")
    }
}

/// Xtream Codes panels expose the whole channel list as an M3U at get.php.
/// `output=m3u8` asks for HLS stream URLs, which AVPlayer can play.
enum XtreamLink {
    static func playlistURL(server: String, username: String, password: String) -> URL? {
        guard let base = ServerAddress.normalize(server, preferringHTTPS: false), !username.isEmpty, !password.isEmpty,
              var components = URLComponents(url: base.appending(path: "get.php"), resolvingAgainstBaseURL: false)
        else { return nil }
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "type", value: "m3u_plus"),
            URLQueryItem(name: "output", value: "m3u8")
        ]
        return components.url
    }
}
