import Foundation
import SwiftData

/// Writes large playlists off the main actor, in its own context per write. Not a `@ModelActor`:
/// that ran on the main thread and stalled the UI for 40 s on 30 000 channels (DECISIONS 47).
actor LibraryWriter {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Replaces the playlist's channels with `entries`, keeping favourites and watch history for each
    /// stream still present, by its link or, when the link changed, by its title. Returns the count.
    @discardableResult
    func replaceChannels(of playlistID: UUID, with entries: [PlaylistEntry]) throws -> Int {
        let modelContext = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<Playlist>(predicate: #Predicate { $0.id == playlistID })
        descriptor.fetchLimit = 1
        guard let playlist = try modelContext.fetch(descriptor).first else { throw LibraryError.notFound }

        let listedURLs = Set(entries.map(\.streamURL.absoluteString))
        var byURL: [String: Kept] = [:]
        // A new login token or server address changes every link. Only links that went away are matched by
        // title, one old row per new row in playlist order, so a same-named backup keeps its own state.
        var byTitle: [TitleKey: [(order: Int, kept: Kept)]] = [:]
        for channel in playlist.channels {
            let kept = Kept(channel)
            byURL[channel.streamURLString] = byURL[channel.streamURLString]?.merged(with: kept) ?? kept
            if !listedURLs.contains(channel.streamURLString) {
                let title = TitleKey(name: channel.name, group: channel.group, year: channel.year)
                byTitle[title, default: []].append((channel.sortIndex, kept))
            }
            modelContext.delete(channel)
        }
        byTitle = byTitle.mapValues { $0.count > 1 ? $0.sorted { $0.order < $1.order } : $0 }
        for (index, entry) in entries.enumerated() {
            let url = entry.streamURL.absoluteString
            var kept = byURL[url]
            let title = TitleKey(name: entry.name, group: entry.group, year: entry.year)
            if kept == nil, let earlier = byTitle[title]?.first {
                kept = earlier.kept
                byTitle[title]?.removeFirst()
            }
            let channel = Channel(
                name: entry.name,
                group: entry.group,
                logoURLString: entry.logoURL?.absoluteString,
                streamURLString: url,
                sortIndex: index,
                isFavorite: kept?.favorite ?? false,
                lastPlayedAt: kept?.played,
                resumePosition: kept?.resumePosition,
                duration: kept?.duration,
                finishedAt: kept?.finishedAt,
                year: entry.year,
                artwork: entry.artwork
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

/// What a refresh carries from an old row to the new row for the same video.
private struct Kept {
    var favorite: Bool
    var played: Date?
    var resumePosition: Double?
    var duration: Double?
    var finishedAt: Date?

    init(_ channel: Channel) {
        favorite = channel.isFavorite
        played = channel.lastPlayedAt
        resumePosition = channel.resumePosition
        duration = channel.duration
        finishedAt = channel.finishedAt
    }

    /// One video listed twice: the favourite if either copy had it, and the latest play with its place.
    func merged(with other: Kept) -> Kept {
        var latest = (other.played ?? .distantPast) > (played ?? .distantPast) ? other : self
        latest.favorite = favorite || other.favorite
        return latest
    }
}

/// A video's title within its source; a film's year tells remakes apart.
private struct TitleKey: Hashable {
    let name: String
    let group: String
    let year: Int?
}
