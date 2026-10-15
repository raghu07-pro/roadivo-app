import Foundation

struct SourceSummary: Identifiable, Hashable {
    let id: UUID
    let name: String
    let kind: PlaylistKind
    let itemCount: Int
    let host: String?
    let refreshedAt: Date?
    /// The server a media-server source signed in to.
    var server: MediaServerKind?

    /// A link or a media server, which can be downloaded again.
    var isRefreshable: Bool {
        kind == .remote || kind == .mediaServer
    }

    var symbol: String {
        switch kind {
        case .remote: "link"
        case .file: "doc.text"
        case .localVideos: "iphone"
        case .mediaServer: "server.rack"
        }
    }
}

/// What the user pasted into the Add Source field.
enum SourceInput: Equatable {
    case empty
    case link(URL)
    /// Raw M3U text (pasted, or from a QR code).
    case content(String)
    case unusable

    init(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            self = .empty
            return
        }
        if !text.contains(where: \.isNewline), let url = URL(string: text), let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme), url.host() != nil {
            self = .link(url)
        } else if Self.looksLikeM3U(text), Self.hasPlayableLink(text) {
            self = .content(text)
        } else {
            self = .unusable
        }
    }

    private static func looksLikeM3U(_ text: String) -> Bool {
        text.prefix(7).uppercased() == "#EXTM3U" || text.range(of: "#EXTINF", options: .caseInsensitive) != nil
    }

    /// The test `M3UParser` applies to each line, stopping at the first link it would keep:
    /// a pasted 100 000-line list is classified on every keystroke, and parsed only when added.
    private static func hasPlayableLink(_ text: String) -> Bool {
        let trimmed = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\u{FEFF}"))
        var rest = text[...]
        while !rest.isEmpty {
            let end = rest.firstIndex(where: \.isNewline) ?? rest.endIndex
            let line = rest[..<end].trimmingCharacters(in: trimmed)
            if line.contains("://"), !line.hasPrefix("#"), let url = URL(string: line),
               let scheme = url.scheme?.lowercased(), playableSchemes.contains(scheme), url.host() != nil {
                return true
            }
            rest = end == rest.endIndex ? rest[end...] : rest[rest.index(after: end)...]
        }
        return false
    }

    private static let playableSchemes: Set = ["http", "https", "rtmp", "rtsp"]
}
