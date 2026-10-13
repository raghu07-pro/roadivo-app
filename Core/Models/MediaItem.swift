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

    var groupTitle: String {
        group.isEmpty ? String(appLocalized: "Other") : group
    }
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
        guard let url = MediaLocation.resolve(streamURLString) else { return nil }
        return MediaItem(
            id: id,
            title: name,
            group: group,
            artworkURL: logoURLString.flatMap(URL.init(string:)),
            streamURL: url,
            isLocalFile: streamURLString.hasPrefix(MediaLocation.localScheme),
            isFavorite: isFavorite
        )
    }
}
