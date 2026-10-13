import Foundation
@testable import Roadivo

/// Serves canned playlist text per URL; never touches the network.
final class StubFetcher: PlaylistFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [URL: Result<String, LibraryError>] = [:]
    private(set) var requested: [URL] = []

    func stub(_ url: URL, with text: String) {
        lock.withLock { responses[url] = .success(text) }
    }

    func stub(_ url: URL, failing error: LibraryError) {
        lock.withLock { responses[url] = .failure(error) }
    }

    func fetchText(from url: URL) async throws -> String {
        let response = lock.withLock {
            requested.append(url)
            return responses[url]
        }
        guard let response else { throw LibraryError.httpStatus(404) }
        return try response.get()
    }
}

/// A media server that signs in anyone with password "pw" and serves `entries`.
final class StubMediaServer: MediaServerConnecting, @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [PlaylistEntry]
    private(set) var libraryCalls = 0

    init(entries: [PlaylistEntry] = Fixtures.serverEntries) {
        self.entries = entries
    }

    func setEntries(_ new: [PlaylistEntry]) {
        lock.withLock { entries = new }
    }

    func signIn(kind: MediaServerKind, baseURL: URL, username: String, password: String) async throws
        -> MediaServerAccount {
        guard password == "pw" else { throw MediaServerError.badCredentials }
        return MediaServerAccount(kind: kind, baseURL: baseURL, userID: "u1", token: "tok")
    }

    func library(for account: MediaServerAccount) async throws -> [PlaylistEntry] {
        lock.withLock {
            libraryCalls += 1
            return entries
        }
    }
}

@MainActor
struct TestLibrary {
    let store: SwiftDataStore
    let secureStore = InMemorySecureStore()
    let fetcher = StubFetcher()
    let mediaServer = StubMediaServer()
    let repository: LibraryRepository

    init() throws {
        store = try SwiftDataStore(inMemory: true)
        repository = LibraryRepository(
            store: store, secureStore: secureStore, fetcher: fetcher, mediaServers: mediaServer
        )
    }
}

enum Fixtures {
    static let playlistURL = URL(string: "https://iptv.example.com/get.php?username=me&password=secret")!

    static let playlist = """
    #EXTM3U
    #EXTINF:-1 tvg-id="news.one" tvg-logo="https://logos.example.com/news1.png" group-title="News",News One
    https://streams.example.com/news1.m3u8
    #EXTINF:-1 group-title="News",News Two
    https://streams.example.com/news2.m3u8
    #EXTINF:-1 group-title="Sports",Football Live
    https://streams.example.com/football.m3u8
    #EXTINF:0,Untitled Movie
    https://vod.example.com/movie.mp4
    """

    static let serverEntries = [
        PlaylistEntry(
            name: "Dune",
            group: "Movies",
            logoURL: nil,
            streamURL: URL(string: "http://nas.local/v/1.m3u8")!
        ),
        PlaylistEntry(
            name: "S1 · E1 — Pilot",
            group: "The Road",
            logoURL: nil,
            streamURL: URL(string: "http://nas.local/v/2.m3u8")!
        )
    ]

    static let hlsStream = """
    #EXTM3U
    #EXT-X-STREAM-INF:BANDWIDTH=1280000,RESOLUTION=1280x720
    low/index.m3u8
    """
}
