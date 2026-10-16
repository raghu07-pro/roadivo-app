import Foundation
import Observation

@Observable
@MainActor
final class CarHubViewModel {
    private(set) var recent: [MediaItem] = []

    private let repository: LibraryRepository
    private let profiles: DisplayProfileStore

    init(repository: LibraryRepository, profiles: DisplayProfileStore) {
        self.repository = repository
        self.profiles = profiles
    }

    func load() {
        // A read failure only hides "Start Car Mode"; the browse button still works.
        recent = (try? repository.recentlyPlayed(limit: 8)) ?? []
    }

    /// What "Start Car Mode" plays when nothing is playing: the last thing watched.
    var resumeItem: MediaItem? {
        recent.first
    }

    /// The connected screen's saved profile, if any.
    func profile(for receiver: Receiver) -> DisplayProfile? {
        profiles.savedProfile(for: receiver)
    }

    /// Saves a profile for the connected screen and returns its id, to open it.
    func saveProfile(for receiver: Receiver) -> UUID {
        profiles.addProfile(for: receiver).id
    }

    func profileEditor(for id: UUID) -> DisplayProfileEditorViewModel? {
        guard let profile = profiles.profile(id: id) else { return nil }
        return DisplayProfileEditorViewModel(profile: profile, store: profiles, repository: repository)
    }
}
