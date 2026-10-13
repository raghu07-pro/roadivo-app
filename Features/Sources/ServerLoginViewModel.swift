import Foundation
import Observation

/// Sign-in form for a Jellyfin, Emby or Xtream server.
@Observable
@MainActor
final class ServerLoginViewModel {
    let kind: MediaServerKind
    var address = ""
    var username = ""
    var password = ""
    var name = ""
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
                try await repository.addXtream(name: name, server: address, username: user, password: password)
            case .jellyfin, .emby:
                try await repository.addMediaServer(
                    kind: kind, name: name, address: address, username: user, password: password
                )
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
