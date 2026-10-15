import Foundation
import SwiftData

/// Writes large playlists off the main actor, in its own context per write. Not a `@ModelActor`:
/// that ran on the main thread and stalled the UI for 40 s on 30 000 channels (DECISIONS 47).
actor LibraryWriter {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Replaces the playlist's channels with `entries`, keeping favourites and
    /// watch history for any stream URL that is still present. Returns the count.
    @discardableResult
    func replaceChannels(of playlistID: UUID, with entries: [PlaylistEntry]) throws -> Int {
        let modelContext = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<Playlist>(predicate: #Predicate { $0.id == playlistID })
        descriptor.fetchLimit = 1
        guard let playlist = try modelContext.fetch(descriptor).first else { throw LibraryError.notFound }

        // A stream listed twice keeps the favourite if either copy had it, and the latest play.
        var kept: [String: (favorite: Bool, played: Date?)] = [:]
        for channel in playlist.channels {
            let earlier = kept[channel.streamURLString]
            let played = [earlier?.played, channel.lastPlayedAt].compactMap(\.self).max()
            kept[channel.streamURLString] = ((earlier?.favorite ?? false) || channel.isFavorite, played)
            modelContext.delete(channel)
        }
        for (index, entry) in entries.enumerated() {
            let url = entry.streamURL.absoluteString
            let channel = Channel(
                name: entry.name,
                group: entry.group,
                logoURLString: entry.logoURL?.absoluteString,
                streamURLString: url,
                sortIndex: index,
                isFavorite: kept[url]?.favorite ?? false,
                lastPlayedAt: kept[url]?.played
            )
            modelContext.insert(channel)
            channel.playlist = playlist
        }
        playlist.refreshedAt = .now
        try modelContext.save()
        return entries.count
    }

    /// Deletes a playlist and, by cascade, its channels off the main actor, so a 30 000-channel
    /// source doesn't freeze the screen. (A store-level batch delete is refused for this relationship.)
    func deletePlaylist(_ playlistID: UUID) throws {
        let modelContext = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<Playlist>(predicate: #Predicate { $0.id == playlistID })
        descriptor.fetchLimit = 1
        guard let playlist = try modelContext.fetch(descriptor).first else { throw LibraryError.notFound }
        modelContext.delete(playlist)
        try modelContext.save()
    }
}
