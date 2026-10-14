import Foundation
import Observation

/// Connect to Plex: show a code for plex.tv/link, wait for it to be entered, pick a server
/// (automatic when there's one), then add its library.
@Observable
@MainActor
final class PlexLoginViewModel {
    enum Step: Equatable {
        case gettingCode
        case waiting(PlexPin)
        case choosing([PlexServer])
        case adding(String)
        case failed(String)
    }

    private(set) var step: Step = .gettingCode
    private let plex: PlexLinking
    private let repository: LibraryRepository
    private let pollInterval: Duration

    init(plex: PlexLinking, repository: LibraryRepository, pollInterval: Duration = .seconds(2)) {
        self.plex = plex
        self.repository = repository
        self.pollInterval = pollInterval
    }

    /// Gets a code and waits for it. Returns true when a server was added; runs until then,
    /// a failure, or the screen goes away (task cancellation).
    func start() async -> Bool {
        step = .gettingCode
        do {
            let pin = try await plex.createPin()
            step = .waiting(pin)
            guard let token = try await waitForToken(pin) else { return false }
            let servers = try await plex.servers(token: token)
            if servers.count == 1, let server = servers.first {
                return await add(server)
            }
            step = .choosing(servers)
        } catch is CancellationError {
            return false
        } catch {
            step = .failed(error.localizedDescription)
        }
        return false
    }

    /// Returns true when the server's library was added.
    func add(_ server: PlexServer) async -> Bool {
        step = .adding(server.name)
        do {
            let account = try await plex.account(for: server)
            try await repository.add(account, name: "", defaultName: "Plex · \(server.name)")
            return true
        } catch {
            step = .failed(error.localizedDescription)
            return false
        }
    }

    private func waitForToken(_ pin: PlexPin) async throws -> String? {
        while Date() < pin.expiresAt {
            try await Task.sleep(for: pollInterval)
            if let token = try await plex.token(for: pin) {
                return token
            }
        }
        throw PlexError.codeExpired
    }
}
