import Foundation
import Observation

@Observable
@MainActor
final class PlayerViewModel {
    let playback: PlaybackController
    private let repository: LibraryRepository

    init(playback: PlaybackController, repository: LibraryRepository) {
        self.playback = playback
        self.repository = repository
    }

    var current: MediaItem? {
        playback.current
    }

    var upNext: [MediaItem] {
        playback.queue
    }

    var errorMessage: String? {
        if case let .failed(message) = playback.status {
            return message
        }
        return nil
    }

    /// Returns true when the favourite changed.
    func toggleFavorite() -> Bool {
        guard let current, let isFavorite = try? repository.toggleFavorite(current.id) else { return false }
        playback.updateFavorite(isFavorite, for: current.id)
        return true
    }

    func select(_ item: MediaItem) {
        guard item.id != current?.id else { return }
        playback.play(item, queue: playback.queue)
    }

    func retry() {
        guard let current else { return }
        playback.play(current, queue: playback.queue)
    }
}
