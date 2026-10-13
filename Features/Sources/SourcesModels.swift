import Foundation

struct SourceSummary: Identifiable, Equatable {
    let id: UUID
    let name: String
    let kind: PlaylistKind
    let itemCount: Int
    let host: String?
    let refreshedAt: Date?

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
        } else if text.uppercased().contains("#EXTINF") || text.uppercased().hasPrefix("#EXTM3U"),
                  !M3UParser.parse(text).isEmpty {
            self = .content(text)
        } else {
            self = .unusable
        }
    }
}
