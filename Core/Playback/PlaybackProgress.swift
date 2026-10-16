import Foundation

/// How far into a video playback got, and the rules for picking it up again (DECISIONS 104).
struct PlaybackProgress: Hashable, Sendable {
    /// Shorter videos always start from the beginning, as in Jellyfin.
    static let shortestResumable: Double = 300
    /// A place under a minute in isn't kept. Jellyfin's 5 % would lose six minutes of a film after a short stop.
    static let earliestResume: Double = 60
    /// Past 90 % the rest is credits, so the video counts as watched (Jellyfin's and Plex's mark).
    static let finishedFraction = 0.9

    let position: Double
    let duration: Double

    /// How much has been watched, from 0 to 1.
    var fraction: Double {
        duration > 0 ? min(max(position / duration, 0), 1) : 0
    }

    var isFinished: Bool {
        fraction >= Self.finishedFraction
    }

    /// Where the next play starts; nil to start from the beginning.
    var resumePoint: Double? {
        guard duration >= Self.shortestResumable, position >= Self.earliestResume, !isFinished else { return nil }
        return position
    }

    var remaining: Double {
        max(duration - position, 0)
    }

    /// "1 hr, 42 min" or "8 min", rounded up to the minute, for "… left".
    func remainingText(locale: Locale) -> String {
        let minutes = max(1, Int((remaining / 60).rounded(.up)))
        return Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
    }
}

/// Where the player reads and keeps each video's place: the library, in the app.
@MainActor
protocol PlaybackProgressStoring: AnyObject {
    func resumePosition(for id: UUID) -> Double?
    func saveProgress(_ progress: PlaybackProgress, for id: UUID)
}
