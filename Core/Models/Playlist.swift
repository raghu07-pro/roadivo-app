import Foundation
import SwiftData

enum PlaylistKind: String, Codable, Sendable {
    /// Downloaded from a link; can be refreshed.
    case remote
    /// Imported once from an .m3u file or pasted text.
    case file
    /// Video files copied into the app ("On this iPhone").
    case localVideos
    /// A signed-in Jellyfin or Emby server; refreshable.
    case mediaServer
}

@Model
final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var createdAt: Date
    var refreshedAt: Date?
    /// The source's host, safe to display. The full link often carries the
    /// provider's username and password, so it lives in the Keychain instead.
    var sourceHost: String?
    /// When a refresh was last tried, and why it failed (nil once one works). For Source Health.
    var lastRefreshAttemptAt: Date?
    var lastRefreshError: String?
    /// Entries the last download listed but couldn't use (`M3UParser.Issues`).
    var skippedWithoutLink: Int?
    var skippedUnsupportedLink: Int?
    /// The last stream check (`StreamCheckReport`, as JSON).
    var streamCheckData: Data?
    @Relationship(deleteRule: .cascade, inverse: \Channel.playlist) var channels: [Channel] = []

    var kind: PlaylistKind {
        PlaylistKind(rawValue: kindRaw) ?? .file
    }

    init(id: UUID = UUID(), name: String, kind: PlaylistKind, createdAt: Date = .now, sourceHost: String? = nil) {
        self.id = id
        self.name = name
        kindRaw = kind.rawValue
        self.createdAt = createdAt
        self.sourceHost = sourceHost
    }
}
