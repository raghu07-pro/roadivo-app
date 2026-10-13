import Foundation
import Observation

@Observable
@MainActor
final class CarHubViewModel {
    private(set) var recent: [MediaItem] = []

    private let repository: LibraryRepository

    init(repository: LibraryRepository) {
        self.repository = repository
    }

    func load() {
        // A read failure only hides "Start Car Mode"; the browse button still works.
        recent = (try? repository.recentlyPlayed(limit: 8)) ?? []
    }

    /// What "Start Car Mode" plays when nothing is playing: the last thing watched.
    var resumeItem: MediaItem? {
        recent.first
    }
}
