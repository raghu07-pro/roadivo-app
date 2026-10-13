import Foundation

/// Parses M3U / M3U8 IPTV playlists (the "extended M3U" dialect IPTV providers use).
///
/// Tolerant by design: real-world playlists ship with a byte-order mark, CRLF
/// line endings, a missing `#EXTM3U` header, unquoted attributes, relative URLs
/// and stray directives. Anything that isn't a resolvable stream URL is skipped
/// rather than failing the whole import.
enum M3UParser {
    /// Parses `text` into entries in playlist order. Relative stream and logo
    /// URLs resolve against `baseURL` (the playlist's own address), but only
    /// once the text has shown it is an extended M3U (`#EXTM3U` or `#EXTINF`).
    /// Otherwise any stray word in a login page or an "Account expired" reply
    /// would resolve to a bogus channel on the provider's host.
    static func parse(_ text: String, baseURL: URL? = nil) -> [PlaylistEntry] {
        var entries: [PlaylistEntry] = []
        var pending: ExtInf?
        var pendingGroup: String?
        var relativeBase: URL?

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\u{FEFF}")))
            guard !line.isEmpty else { continue }

            if line.hasPrefix("#") {
                let directive = line.uppercased()
                if directive.hasPrefix("#EXTINF:") {
                    pending = ExtInf(line: String(line.dropFirst("#EXTINF:".count)))
                    relativeBase = baseURL
                } else if directive.hasPrefix("#EXTGRP:") {
                    pendingGroup = String(line.dropFirst("#EXTGRP:".count)).trimmingCharacters(in: .whitespaces)
                } else if directive.hasPrefix("#EXTM3U") {
                    relativeBase = baseURL
                }
                continue
            }

            guard let streamURL = resolve(line, against: relativeBase) else {
                pending = nil
                pendingGroup = nil
                continue
            }
            let info = pending
            let name = [info?.title, info?.attributes["tvg-name"]]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty } ?? fallbackName(for: streamURL)
            let group = info?.attributes["group-title"].flatMap { $0.isEmpty ? nil : $0 } ?? pendingGroup ?? ""
            let logo = info?.attributes["tvg-logo"].flatMap { resolve($0, against: relativeBase) }
            entries.append(PlaylistEntry(name: name, group: group, logoURL: logo, streamURL: streamURL))
            pending = nil
            pendingGroup = nil
        }
        return entries
    }

    /// True when `text` is an HLS media or master playlist (a single stream),
    /// not an IPTV channel list. Such a URL is added as one channel instead.
    static func isHLSStream(_ text: String) -> Bool {
        text.contains("#EXT-X-STREAM-INF") || text.contains("#EXT-X-TARGETDURATION")
            || text.contains("#EXT-X-MEDIA-SEQUENCE")
    }

    /// True when downloaded text is a web page, XML or a JSON reply rather than
    /// a playlist: what a hotel or café Wi-Fi sign-in page, a provider's login
    /// page or an expired account sends back with a 200 status.
    static func looksLikeWebPage(_ text: String) -> Bool {
        let start = text.first { !$0.isWhitespace && $0 != "\u{FEFF}" }
        return start == "<" || start == "{" || start == "["
    }

    static func fallbackName(for url: URL) -> String {
        let last = url.deletingPathExtension().lastPathComponent
        return last.isEmpty || last == "/" ? (url.host() ?? url.absoluteString) : last
    }

    /// Network schemes only: a playlist from the internet must never point
    /// the player at files on the device.
    private static let playableSchemes: Set = ["http", "https", "rtmp", "rtsp"]

    private static func resolve(_ string: String, against baseURL: URL?) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let absolute = URL(string: trimmed), let scheme = absolute.scheme?.lowercased() {
            return playableSchemes.contains(scheme) && absolute.host() != nil ? absolute : nil
        }
        // A relative reference must already be a valid URL as written. iOS 17's
        // lenient parsing would otherwise percent-encode "<html>" or a sentence
        // into a path.
        guard let baseURL,
              URL(string: trimmed, encodingInvalidCharacters: false) != nil,
              let relative = URL(string: trimmed, relativeTo: baseURL) else { return nil }
        return relative.absoluteURL
    }
}

/// The parsed `#EXTINF:<duration> key="value" …,<title>` directive.
private struct ExtInf {
    var title: String?
    var attributes: [String: String] = [:]

    init(line: String) {
        // The title follows the first comma that is not inside quotes.
        var inQuotes = false
        var splitIndex: String.Index?
        for index in line.indices {
            let character = line[index]
            if character == "\"" {
                inQuotes.toggle()
            }
            if character == ",", !inQuotes {
                splitIndex = index
                break
            }
        }
        let head = splitIndex.map { String(line[..<$0]) } ?? line
        title = splitIndex.map { String(line[line.index(after: $0)...]) }
        attributes = Self.attributes(in: head)
    }

    /// Reads `key="value"` and `key=value` pairs; keys are lower-cased.
    private static func attributes(in text: String) -> [String: String] {
        var result: [String: String] = [:]
        var scanner = Substring(text)
        while let equals = scanner.firstIndex(of: "=") {
            let key = scanner[..<equals].split(separator: " ").last.map(String.init)?.lowercased() ?? ""
            var rest = scanner[scanner.index(after: equals)...]
            let value: Substring
            if rest.first == "\"" {
                rest = rest.dropFirst()
                let close = rest.firstIndex(of: "\"") ?? rest.endIndex
                value = rest[..<close]
                scanner = close < rest.endIndex ? rest[rest.index(after: close)...] : ""
            } else {
                let end = rest.firstIndex(of: " ") ?? rest.endIndex
                value = rest[..<end]
                scanner = rest[end...]
            }
            if !key.isEmpty {
                result[key] = value.trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }
}
