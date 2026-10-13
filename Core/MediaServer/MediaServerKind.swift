import Foundation

/// The server types "Or connect a media server" offers.
enum MediaServerKind: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case jellyfin
    case emby
    case xtream

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .jellyfin: "Jellyfin"
        case .emby: "Emby"
        case .xtream: "Xtream"
        }
    }

    var symbol: String {
        switch self {
        case .jellyfin: "triangle.fill"
        case .emby: "play.rectangle.fill"
        case .xtream: "play.tv.fill"
        }
    }

    var addressPlaceholder: String {
        switch self {
        case .jellyfin: "http://192.168.1.10:8096"
        case .emby: "http://192.168.1.10:8096"
        case .xtream: "http://provider.example.com:8080"
        }
    }
}

/// Turns what a user types ("192.168.1.10:8096", "https://tv.example.com/")
/// into a base URL: http assumed when no scheme is given, trailing "/" dropped.
enum ServerAddress {
    static func normalize(_ raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(" ") else { return nil }
        if !text.lowercased().hasPrefix("http://"), !text.lowercased().hasPrefix("https://") {
            text = "http://" + text
        }
        while text.hasSuffix("/") {
            text.removeLast()
        }
        guard let url = URL(string: text), url.host() != nil else { return nil }
        return url
    }
}

/// Xtream Codes panels expose the whole channel list as an M3U at get.php.
/// `output=m3u8` asks for HLS stream URLs, which AVPlayer can play.
enum XtreamLink {
    static func playlistURL(server: String, username: String, password: String) -> URL? {
        guard let base = ServerAddress.normalize(server), !username.isEmpty, !password.isEmpty,
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
