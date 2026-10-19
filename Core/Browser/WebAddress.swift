import Foundation

/// What the Browser's address bar makes of what's typed: a web address as it is, a bare site or home
/// server ("example.com", "192.168.1.10:8096") with a scheme added, and anything else as a web search.
enum WebAddress {
    /// Words that aren't an address are searched here (DECISIONS 118).
    static let searchEngine = "https://www.google.com/search"

    static func url(for input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let url = URL(string: text), isWeb(url), url.host() != nil {
            return url
        }
        if !text.contains(" "), looksLikeHost(text),
           let url = URL(string: (isOnHomeNetwork(text) ? "http://" : "https://") + text), url.host() != nil {
            return url
        }
        var search = URLComponents(string: searchEngine)
        search?.queryItems = [URLQueryItem(name: "q", value: text)]
        return search?.url
    }

    /// The site's name for the address bar and lists: "example.com" for https://www.example.com/a.
    static func displayName(of url: URL) -> String {
        guard let host = url.host(), !host.isEmpty else { return url.absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    static func isWeb(_ url: URL?) -> Bool {
        guard let scheme = url?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// The host part of what was typed, without a path or port.
    private static func host(in text: String) -> String {
        let beforePath = text.split(separator: "/", maxSplits: 1).first.map(String.init) ?? text
        return (beforePath.split(separator: ":", maxSplits: 1).first.map(String.init) ?? beforePath).lowercased()
    }

    private static func looksLikeHost(_ text: String) -> Bool {
        let host = host(in: text)
        if host == "localhost" || isIPv4(host) {
            return true
        }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }), let domain = labels.last else { return false }
        return domain.count >= 2 && domain.allSatisfy(\.isLetter)
    }

    /// Home servers rarely have a certificate, so they get plain http.
    private static func isOnHomeNetwork(_ text: String) -> Bool {
        let host = host(in: text)
        return host == "localhost" || isIPv4(host) || host.hasSuffix(".local")
    }

    private static func isIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { part in Int(part).map { (0...255).contains($0) } ?? false }
    }
}

/// A video on a web page that Roadivo's own player can take: an HLS stream or a video file. A channel
/// list (.m3u) is a source, not a video, so it stays with the page.
enum WebMedia {
    private static let types: Set<String> = [
        "application/vnd.apple.mpegurl", "application/x-mpegurl", "video/mp4", "video/quicktime", "video/x-m4v"
    ]
    private static let extensions: Set<String> = ["m3u8", "mp4", "m4v", "mov"]

    /// A page that is itself a video: by the type its server gives, or by the name of the file.
    static func isPlayablePage(_ url: URL?, mimeType: String?) -> Bool {
        guard let url, WebAddress.isWeb(url), url.pathExtension.lowercased() != "m3u" else { return false }
        if let type = mimeType?.lowercased(), types.contains(type) {
            return true
        }
        return extensions.contains(url.pathExtension.lowercased())
    }

    /// A `<video>` the page started: Safari can play it, so AVPlayer can, unless it's a stream the page
    /// assembles itself (a blob: address) or a channel list.
    static func isPlayableSource(_ url: URL?) -> Bool {
        guard let url, WebAddress.isWeb(url) else { return false }
        return url.pathExtension.lowercased() != "m3u"
    }
}
