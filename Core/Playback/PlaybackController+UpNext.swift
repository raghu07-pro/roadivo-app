import UIKit

/// After a video ends: the next one, counting down so there's a moment to stop it (DECISIONS 115).
struct UpNext: Equatable {
    let item: MediaItem
    var secondsLeft: Int
    /// The countdown's length, for its ring.
    let total: Int

    /// How much of the countdown is left, from 1 down to 0.
    var fraction: Double {
        total > 0 ? Double(secondsLeft) / Double(total) : 0
    }
}

extension PlaybackController {
    /// Counts down to `item`; in the background it plays at once, as a pause there could let iOS suspend
    /// the app and stop the trip's sound.
    func countDown(to item: MediaItem) {
        cancelUpNext()
        guard isInForeground() else {
            next()
            return
        }
        let delay = upNextDelay
        upNext = UpNext(item: item, secondsLeft: delay, total: delay)
        // From here, not the card: minimised, no card is on screen to say it.
        UIAccessibility.post(notification: .announcement, argument: String(appLocalized: "Up next: \(item.title)"))
        upNextTask = Task { [weak self] in
            for remaining in stride(from: delay - 1, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1)) // Cut short when the user acts first.
                guard !Task.isCancelled, let self else { return }
                upNext?.secondsLeft = remaining
            }
            guard !Task.isCancelled else { return }
            self?.playUpNextNow()
        }
    }

    /// Plays the card's video, unless a refresh or delete took it out of the queue meanwhile.
    func playUpNextNow() {
        guard let item = upNext?.item else { return }
        cancelUpNext()
        if let target = queue.first(where: { $0.id == item.id }) {
            play(target, queue: queue, from: origin)
        }
    }

    /// Stays on the video that ended.
    func cancelUpNext() {
        upNextTask?.cancel()
        upNextTask = nil
        upNext = nil
    }

    /// Sent to the background mid-countdown, the next video starts now rather than never.
    func enteredBackground() {
        if upNext != nil {
            playUpNextNow()
        }
    }
}
