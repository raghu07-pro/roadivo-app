import Foundation
import Observation
import OSLog

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
    /// Why the last server couldn't be added; shown above the server list so another can be tried.
    private(set) var errorMessage: String?
    private var servers: [PlexServer] = []
    private let plex: PlexLinking
    private let repository: LibraryRepository
    private let pollInterval: Duration
    private let logger = Logger(subsystem: "com.roadivo", category: "Plex")

    init(plex: PlexLinking, repository: LibraryRepository, pollInterval: Duration = .seconds(2)) {
        self.plex = plex
        self.repository = repository
        self.pollInterval = pollInterval
    }

    /// Gets a code and waits for it. Returns true when a server was added; runs until then,
    /// a failure, or the screen goes away (task cancellation).
    func start() async -> Bool {
        step = .gettingCode
        errorMessage = nil
        do {
            let pin = try await plex.createPin()
            step = .waiting(pin)
            guard let token = try await waitForToken(pin) else { return false }
            servers = try await plex.servers(token: token)
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

    /// Returns true when the server's library was added. On failure the server list comes back with
    /// the error, since the sign-in is still good: no new code needed.
    func add(_ server: PlexServer) async -> Bool {
        step = .adding(server.name)
        errorMessage = nil
        do {
            let account = try await plex.account(for: server)
            try await repository.add(account, name: "", defaultName: "Plex · \(server.name)")
            return true
        } catch {
            errorMessage = error.localizedDescription
            step = .choosing(servers.isEmpty ? [server] : servers)
            return false
        }
    }

    /// Polls until the code is entered. A failed poll (Safari in front, a 5xx, a 429) is retried with
    /// a growing pause; only an unknown code (404) or expiry ends the wait.
    private func waitForToken(_ pin: PlexPin) async throws -> String? {
        var pause = pollInterval
        while Date() < pin.expiresAt {
            try await Task.sleep(for: pause)
            do {
                if let token = try await plex.token(for: pin) {
                    return token
                }
                pause = pollInterval
            } catch PlexError.codeExpired {
                throw PlexError.codeExpired
            } catch {
                try Task.checkCancellation()
                logger.notice("Plex poll failed, retrying: \(error.localizedDescription, privacy: .public)")
                pause = min(pause * 2, max(pollInterval, .seconds(15)))
            }
        }
        throw PlexError.codeExpired
    }
}
