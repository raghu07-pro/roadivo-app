import Foundation

/// A value snapshot of a `Channel`, safe to hand to views and the player.
struct MediaItem: Hashable, Identifiable, Sendable {
    let id: UUID
    let title: String
    /// The group, or empty.
    let group: String
    let artworkURL: URL?
    let streamURL: URL
    let isLocalFile: Bool
    var isFavorite: Bool
    /// The source (playlist) it came from, for browsing its other groups.
    var sourceID: UUID?
    /// A film's release year, from a media server.
    var year: Int?
    var artwork: ArtworkStyle = .logo

    var groupTitle: String {
        group.isEmpty ? String(appLocalized: "Other") : group
    }
}

/// How an item's picture is drawn: a channel logo on a coloured tile, or a server's 16:9 still or 2:3 poster.
enum ArtworkStyle: String, Sendable {
    case logo
    case still
    case poster
}

/// Where an imported video lives. Stored as a file name, not an absolute path:
/// the app container's path changes between installs and updates.
enum MediaLocation {
    static let localScheme = "roadivo-local:"

    static var videosDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Videos", directoryHint: .isDirectory)
    }

    static func resolve(_ stored: String) -> URL? {
        if stored.hasPrefix(localScheme) {
            return videosDirectory.appending(path: String(stored.dropFirst(localScheme.count)))
        }
        return URL(string: stored)
    }
}

extension Channel {
    var mediaItem: MediaItem? {
        mediaItem(sourceID: playlist?.id)
    }

    /// With the source already known, so a big fetch doesn't read every channel's playlist.
    func mediaItem(sourceID: UUID?) -> MediaItem? {
        guard let url = MediaLocation.resolve(streamURLString) else { return nil }
        return MediaItem(
            id: id,
            title: name,
            group: group,
            artworkURL: logoURLString.flatMap(URL.init(string:)),
            streamURL: url,
            isLocalFile: streamURLString.hasPrefix(MediaLocation.localScheme),
            isFavorite: isFavorite,
            sourceID: sourceID,
            year: year,
            artwork: artworkRaw.flatMap(ArtworkStyle.init(rawValue:)) ?? .logo
        )
    }
}
