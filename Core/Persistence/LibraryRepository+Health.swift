import Foundation
import OSLog
import SwiftData

// MARK: - Source Health

extension LibraryRepository {
    func health(of playlistID: UUID) throws -> SourceHealth {
        let playlist = try playlist(playlistID)
        return try SourceHealth(
            kind: playlist.kind,
            channelCount: channelCount(in: playlistID),
            refreshedAt: playlist.refreshedAt,
            lastRefreshAttemptAt: playlist.lastRefreshAttemptAt,
            lastRefreshError: playlist.lastRefreshError,
            issues: playlist.issues,
            streamCheck: playlist.streamCheck
        )
    }

    func saveStreamCheck(_ report: StreamCheckReport, for playlistID: UUID) throws {
        try playlist(playlistID).streamCheckData = JSONEncoder().encode(report)
        try context.save()
    }

    /// Keeps a refresh's outcome. Best effort: failing to note it must not fail the refresh.
    func recordRefresh(of playlistID: UUID, issues: M3UParser.Issues?, error: (any Error)?) {
        do {
            let playlist = try playlist(playlistID)
            playlist.lastRefreshAttemptAt = .now
            playlist.lastRefreshError = error?.localizedDescription
            if let issues {
                playlist.record(issues)
            }
            try context.save()
        } catch {
            logger.error("Recording a refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Where to ask a media server whether it's up; both need no login.
    func serverCheckURL(for playlistID: UUID) -> URL? {
        guard let stored = try? secureStore.string(for: sourceKey(playlistID)),
              let account = try? JSONDecoder().decode(MediaServerAccount.self, from: Data(stored.utf8))
        else { return nil }
        return account.baseURL.appending(path: account.kind == .plex ? "identity" : "System/Info/Public")
    }

    /// Videos on this iPhone whose copied file is gone.
    func missingVideos() throws -> [MediaItem] {
        try localVideos().filter { !FileManager.default.fileExists(atPath: $0.streamURL.path()) }
    }
}
