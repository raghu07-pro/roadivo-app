import Foundation

/// A playback time as the player and Car Mode show it.
enum PlaybackClock {
    /// "0:07", "12:40" or "1:02:05"; anything not a number reads "0:00".
    static func text(_ seconds: Double) -> String {
        let total = Int(seconds.isFinite ? max(0, seconds) : 0)
        let (hours, minutes, secs) = (total / 3600, total % 3600 / 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
