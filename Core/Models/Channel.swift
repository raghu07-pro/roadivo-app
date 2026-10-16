import Foundation
import SwiftData

/// A playable item: a live channel, a VOD entry, or a local video file.
@Model
final class Channel {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Empty when the playlist gave no group; shown as "Other".
    var group: String
    var logoURLString: String?
    /// A remote URL, or `MediaLocation.localScheme` + file name for an imported video.
    var streamURLString: String
    var sortIndex: Int
    var isFavorite: Bool
    var lastPlayedAt: Date?
    /// Seconds in, where the next play picks up; nil starts from the beginning.
    var resumePosition: Double?
    /// The video's length in seconds when last played; nil for a live stream or one never loaded.
    var duration: Double?
    /// When it was last watched to the end, which takes it out of Continue Watching.
    var finishedAt: Date?
    /// A film's year, from a media server.
    var year: Int?
    /// An `ArtworkStyle`; nil is a logo.
    var artworkRaw: String?
    var playlist: Playlist?

    init(
        id: UUID = UUID(),
        name: String,
        group: String,
        logoURLString: String?,
        streamURLString: String,
        sortIndex: Int,
        isFavorite: Bool = false,
        lastPlayedAt: Date? = nil,
        resumePosition: Double? = nil,
        duration: Double? = nil,
        finishedAt: Date? = nil,
        year: Int? = nil,
        artwork: ArtworkStyle = .logo
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.logoURLString = logoURLString
        self.streamURLString = streamURLString
        self.sortIndex = sortIndex
        self.isFavorite = isFavorite
        self.lastPlayedAt = lastPlayedAt
        self.resumePosition = resumePosition
        self.duration = duration
        self.finishedAt = finishedAt
        self.year = year
        artworkRaw = artwork == .logo ? nil : artwork.rawValue
    }
}
