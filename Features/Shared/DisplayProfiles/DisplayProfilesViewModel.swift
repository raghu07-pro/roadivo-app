import Foundation
import Observation

/// Settings › Car & Display Profiles: This iPhone, the saved cars and displays, and saving the one
/// connected now.
@Observable
@MainActor
final class DisplayProfilesViewModel {
    private let store: DisplayProfileStore
    private let connection: CarConnection
    private let repository: LibraryRepository

    init(store: DisplayProfileStore, connection: CarConnection, repository: LibraryRepository) {
        self.store = store
        self.connection = connection
        self.repository = repository
    }

    var thisIPhone: DisplayProfile {
        store.thisIPhone
    }

    var saved: [DisplayProfile] {
        store.saved
    }

    /// The car or display connected now that has no profile yet, to offer saving one.
    var unsavedReceiver: Receiver? {
        guard let receiver = connection.receiver, store.savedProfile(for: receiver) == nil else { return nil }
        return receiver
    }

    /// The profile in use now.
    var activeID: UUID {
        store.profile(for: connection.receiver).id
    }

    /// Saves a profile for the connected receiver and returns its id, to open it.
    func saveCurrentReceiver() -> UUID? {
        connection.receiver.map { store.addProfile(for: $0).id }
    }

    func delete(_ id: UUID) {
        store.delete(id)
    }

    func editor(for id: UUID) -> DisplayProfileEditorViewModel? {
        store.profile(id: id).map { DisplayProfileEditorViewModel(profile: $0, store: store, repository: repository) }
    }
}
