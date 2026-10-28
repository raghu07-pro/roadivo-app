import Foundation
import Testing
@testable import PlayCarTV

@Suite("Connect to Plex")
@MainActor
struct PlexLoginViewModelTests {
    private func server(_ name: String) throws -> PlexServer {
        let uri = try #require(URL(string: "https://\(name.lowercased()).plex.direct:32400"))
        return PlexServer(
            id: name,
            name: name,
            isOwned: true,
            accessToken: "srv",
            connections: [PlexConnection(uri: uri, isLocal: true, isRelay: false)]
        )
    }

    @Test("Shows the code, waits for it, then adds the only server as a source")
    func singleServer() async throws {
        let library = try TestLibrary()
        let plex = try FakePlex(tokenAfterPolls: 2, servers: [server("Den")])
        let viewModel = PlexLoginViewModel(plex: plex, repository: library.repository, pollInterval: .milliseconds(5))
        let added = await viewModel.start()
        #expect(added)
        #expect(plex.polls >= 2)
        #expect(try library.repository.playlists().map(\.name) == ["Plex · Den"])
    }

    @Test("With several servers, the user picks one")
    func choosing() async throws {
        let library = try TestLibrary()
        let servers = try [server("Den"), server("Cabin")]
        let viewModel = PlexLoginViewModel(
            plex: FakePlex(tokenAfterPolls: 0, servers: servers),
            repository: library.repository,
            pollInterval: .milliseconds(5)
        )
        #expect(await viewModel.start() == false)
        #expect(viewModel.step == .choosing(servers))
        #expect(await viewModel.add(servers[1]))
        #expect(try library.repository.playlists().map(\.name) == ["Plex · Cabin"])
    }

    @Test("A code nobody enters expires, with a way to get a new one")
    func expired() async throws {
        let viewModel = try PlexLoginViewModel(
            plex: FakePlex(tokenAfterPolls: nil, servers: [], lifetime: 0.05),
            repository: TestLibrary().repository,
            pollInterval: .milliseconds(10)
        )
        #expect(await viewModel.start() == false)
        #expect(viewModel.step == .failed(PlexError.codeExpired.localizedDescription))
    }

    @Test("An unreachable server is reported, not added, and can be tried again without a new code")
    func unreachable() async throws {
        let library = try TestLibrary()
        let den = try server("Den")
        let plex = FakePlex(tokenAfterPolls: 0, servers: [den], reachable: false)
        let viewModel = PlexLoginViewModel(plex: plex, repository: library.repository, pollInterval: .milliseconds(5))
        #expect(await viewModel.start() == false)
        #expect(viewModel.step == .choosing([den]))
        #expect(viewModel.errorMessage == PlexError.serverUnreachable.localizedDescription)
        #expect(try library.repository.playlists().isEmpty)

        plex.setReachable(true)
        #expect(await viewModel.add(den))
        #expect(viewModel.errorMessage == nil)
        #expect(try library.repository.playlists().map(\.name) == ["Plex · Den"])
    }

    @Test("A chosen server that fails returns to the list with the error")
    func choosingFailure() async throws {
        let library = try TestLibrary()
        let servers = try [server("Den"), server("Cabin")]
        let viewModel = PlexLoginViewModel(
            plex: FakePlex(tokenAfterPolls: 0, servers: servers, reachable: false),
            repository: library.repository,
            pollInterval: .milliseconds(5)
        )
        #expect(await viewModel.start() == false)
        #expect(await viewModel.add(servers[1]) == false)
        #expect(viewModel.step == .choosing(servers))
        #expect(viewModel.errorMessage == PlexError.serverUnreachable.localizedDescription)
    }

    @Test("A lost connection, a 5xx or a 429 while waiting doesn't end the sign-in")
    func transientPollFailures() async throws {
        let library = try TestLibrary()
        let plex = try FakePlex(
            tokenAfterPolls: 4,
            servers: [server("Den")],
            failingPolls: [
                MediaServerError.unreachable("The network connection was lost."),
                MediaServerError.httpStatus(503),
                MediaServerError.httpStatus(429)
            ]
        )
        let viewModel = PlexLoginViewModel(plex: plex, repository: library.repository, pollInterval: .milliseconds(5))
        #expect(await viewModel.start())
        #expect(plex.polls == 4)
        #expect(try library.repository.playlists().map(\.name) == ["Plex · Den"])
    }

    @Test("An unknown code (404) ends the wait at once")
    func unknownCode() async throws {
        let plex = FakePlex(tokenAfterPolls: nil, servers: [], failingPolls: [PlexError.codeExpired])
        let viewModel = try PlexLoginViewModel(
            plex: plex,
            repository: TestLibrary().repository,
            pollInterval: .milliseconds(5)
        )
        #expect(await viewModel.start() == false)
        #expect(viewModel.step == .failed(PlexError.codeExpired.localizedDescription))
        #expect(plex.polls == 1)
    }
}

/// plex.tv without the network: confirms the code after `tokenAfterPolls` checks (never when nil);
/// the first checks throw `failingPolls` in turn.
private final class FakePlex: PlexLinking, @unchecked Sendable {
    private let lock = NSLock()
    private var pollCount = 0
    private var isReachable: Bool
    let tokenAfterPolls: Int?
    let serverList: [PlexServer]
    let lifetime: TimeInterval
    let failingPolls: [any Error]

    init(
        tokenAfterPolls: Int?,
        servers: [PlexServer],
        lifetime: TimeInterval = 60,
        reachable: Bool = true,
        failingPolls: [any Error] = []
    ) {
        self.tokenAfterPolls = tokenAfterPolls
        serverList = servers
        self.lifetime = lifetime
        isReachable = reachable
        self.failingPolls = failingPolls
    }

    var polls: Int {
        lock.withLock { pollCount }
    }

    func setReachable(_ reachable: Bool) {
        lock.withLock { isReachable = reachable }
    }

    func createPin() async throws -> PlexPin {
        PlexPin(id: 1, code: "ABCD", expiresAt: Date().addingTimeInterval(lifetime))
    }

    func token(for pin: PlexPin) async throws -> String? {
        let count = lock.withLock {
            pollCount += 1
            return pollCount
        }
        if count <= failingPolls.count {
            throw failingPolls[count - 1]
        }
        guard let tokenAfterPolls, count > tokenAfterPolls - 1 else { return nil }
        return "user-token"
    }

    func servers(token: String) async throws -> [PlexServer] {
        serverList
    }

    func account(for server: PlexServer) async throws -> MediaServerAccount {
        guard lock.withLock({ isReachable }), let uri = server.connections.first?.uri else {
            throw PlexError.serverUnreachable
        }
        return MediaServerAccount(kind: .plex, baseURL: uri, userID: server.id, token: server.accessToken)
    }
}
