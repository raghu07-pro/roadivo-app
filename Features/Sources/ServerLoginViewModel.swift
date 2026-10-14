import Foundation
import Observation

/// Sign-in form for a Jellyfin, Emby or Xtream server (Plex uses `PlexLoginViewModel`).
@Observable
@MainActor
final class ServerLoginViewModel {
    let kind: MediaServerKind
    var address = ""
    var username = ""
    var password = ""
    private(set) var isConnecting = false
    var errorMessage: String?

    private let repository: LibraryRepository

    init(kind: MediaServerKind, repository: LibraryRepository) {
        self.kind = kind
        self.repository = repository
    }

    /// Xtream needs a password; Jellyfin and Emby allow accounts without one.
    var canConnect: Bool {
        guard !isConnecting, ServerAddress.normalize(address) != nil,
              !username.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return kind != .xtream || !password.isEmpty
    }

    /// Returns true when the server was added.
    func connect() async -> Bool {
        guard canConnect else { return false }
        isConnecting = true
        errorMessage = nil
        defer { isConnecting = false }
        let user = username.trimmingCharacters(in: .whitespaces)
        do {
            switch kind {
            case .xtream:
                // Default names ("Xtream · host"); renamed in Manage Sources if wanted.
                try await repository.addXtream(name: "", server: address, username: user, password: password)
            case .jellyfin, .emby:
                try await repository.addMediaServer(
                    kind: kind, name: "", address: address, username: user, password: password
                )
            case .plex:
                return false // Plex signs in with a code on its own screen.
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
