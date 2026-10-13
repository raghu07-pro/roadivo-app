import Foundation
import SwiftData

/// Writes large playlists off the main actor. A 10 000-channel import would
/// otherwise freeze the UI while SwiftData inserts.
///
/// A plain actor that opens its own context for each write, not a
/// `@ModelActor`: a model actor ran its work on the main thread wherever it was
/// created, and saving 30 000 channels stalled the UI for 40 s (DECISIONS 47).
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

        var kept: [String: (favorite: Bool, played: Date?)] = [:]
        for channel in playlist.channels {
            kept[channel.streamURLString] = (channel.isFavorite, channel.lastPlayedAt)
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
}
