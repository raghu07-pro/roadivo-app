import Foundation
import Testing
@testable import Roadivo

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

    @Test("An unreachable server is reported, not added")
    func unreachable() async throws {
        let library = try TestLibrary()
        let plex = try FakePlex(tokenAfterPolls: 0, servers: [server("Den")], reachable: false)
        let viewModel = PlexLoginViewModel(plex: plex, repository: library.repository, pollInterval: .milliseconds(5))
        #expect(await viewModel.start() == false)
        #expect(viewModel.step == .failed(PlexError.serverUnreachable.localizedDescription))
        #expect(try library.repository.playlists().isEmpty)
    }
}

/// plex.tv without the network: confirms the code after `tokenAfterPolls` checks (never when nil).
private final class FakePlex: PlexLinking, @unchecked Sendable {
    private let lock = NSLock()
    private var pollCount = 0
    let tokenAfterPolls: Int?
    let serverList: [PlexServer]
    let lifetime: TimeInterval
    let reachable: Bool

    init(tokenAfterPolls: Int?, servers: [PlexServer], lifetime: TimeInterval = 60, reachable: Bool = true) {
        self.tokenAfterPolls = tokenAfterPolls
        serverList = servers
        self.lifetime = lifetime
        self.reachable = reachable
    }

    var polls: Int {
        lock.withLock { pollCount }
    }

    func createPin() async throws -> PlexPin {
        PlexPin(id: 1, code: "ABCD", expiresAt: Date().addingTimeInterval(lifetime))
    }

    func token(for pin: PlexPin) async throws -> String? {
        let count = lock.withLock {
            pollCount += 1
            return pollCount
        }
        guard let tokenAfterPolls, count > tokenAfterPolls - 1 else { return nil }
        return "user-token"
    }

    func servers(token: String) async throws -> [PlexServer] {
        serverList
    }

    func account(for server: PlexServer) async throws -> MediaServerAccount {
        guard reachable, let uri = server.connections.first?.uri else { throw PlexError.serverUnreachable }
        return MediaServerAccount(kind: .plex, baseURL: uri, userID: server.id, token: server.accessToken)
    }
}
