import Foundation
import SwiftData

/// Watch history: each video's place, kept as it plays, and taking items out of Continue Watching.
extension LibraryRepository: PlaybackProgressStoring {
    /// The most recently played items, finished or not (CarPlay's Recent, the Car tab).
    func recentlyPlayed(limit: Int = 12) throws -> [MediaItem] {
        try lastPlayed(#Predicate { $0.lastPlayedAt != nil }, limit: limit)
    }

    /// Home's Continue Watching: played and not watched to the end, optionally from one source. Imported
    /// videos are left out inside the fetch, so the row still gets `limit` items.
    func continueWatching(limit: Int = 12, in playlistID: UUID? = nil) throws -> [MediaItem] {
        let localPrefix = MediaLocation.localScheme
        if let playlistID {
            return try lastPlayed(
                #Predicate { $0.lastPlayedAt != nil && $0.finishedAt == nil && $0.playlist?.id == playlistID },
                limit: limit
            )
        }
        return try lastPlayed(
            #Predicate {
                $0.lastPlayedAt != nil && $0.finishedAt == nil && !$0.streamURLString.starts(with: localPrefix)
            },
            limit: limit
        )
    }

    private func lastPlayed(_ predicate: Predicate<Channel>, limit: Int) throws -> [MediaItem] {
        var descriptor = FetchDescriptor<Channel>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).compactMap(\.mediaItem)
    }

    /// Every video's place that can be picked up, to refresh the cards' bars without re-reading the library.
    func playbackProgress() throws -> [UUID: PlaybackProgress] {
        let channels = try context.fetch(FetchDescriptor<Channel>(predicate: #Predicate { $0.resumePosition != nil }))
        return channels.reduce(into: [:]) { result, channel in
            if let position = channel.resumePosition, let duration = channel.duration {
                result[channel.id] = PlaybackProgress(position: position, duration: duration)
            }
        }
    }

    func resumePosition(for id: UUID) -> Double? {
        // Unreadable, the video simply starts from the beginning.
        try? channel(id).resumePosition
    }

    func saveProgress(_ progress: PlaybackProgress, for id: UUID) {
        do {
            let channel = try channel(id)
            channel.duration = progress.duration
            channel.resumePosition = progress.resumePoint
            if !progress.isFinished {
                channel.finishedAt = nil
            } else if channel.finishedAt == nil {
                channel.finishedAt = .now
            }
            try context.save()
        } catch LibraryError.notFound {
            // A refresh or a deleted source took the row; there's nothing left to keep.
        } catch {
            logger.error("saveProgress failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Takes an item out of Continue Watching and Recent, and forgets its place.
    func removeFromHistory(_ id: UUID) throws {
        let channel = try channel(id)
        channel.lastPlayedAt = nil
        channel.resumePosition = nil
        channel.duration = nil
        channel.finishedAt = nil
        try context.save()
    }
}
