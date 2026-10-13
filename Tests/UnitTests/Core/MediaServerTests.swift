import Foundation
import Testing
@testable import Roadivo

/// Its own URLProtocol so these tests never race APIClientTests' handler.
final class ServerMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        let (status, data) = handler(request)
        if let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("Media servers", .serialized)
struct MediaServerTests {
    private func client() -> EmbyCompatibleClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ServerMockURLProtocol.self]
        return EmbyCompatibleClient(session: URLSession(configuration: configuration), deviceID: "dev-1")
    }

    @Test("Server addresses gain http:// and lose trailing slashes")
    func normalize() {
        #expect(ServerAddress.normalize("192.168.1.10:8096")?.absoluteString == "http://192.168.1.10:8096")
        #expect(ServerAddress.normalize(" https://tv.example.com/ ")?.absoluteString == "https://tv.example.com")
        #expect(ServerAddress.normalize("") == nil)
        #expect(ServerAddress.normalize("not a server") == nil)
    }

    @Test("Xtream logins become an HLS M3U link")
    func xtream() throws {
        let url = try #require(XtreamLink.playlistURL(
            server: "panel.example.com:8080",
            username: "me",
            password: "p@ss"
        ))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "panel.example.com")
        #expect(components.path == "/get.php")
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(query == ["username": "me", "password": "p@ss", "type": "m3u_plus", "output": "m3u8"])
        #expect(XtreamLink.playlistURL(server: "panel.example.com", username: "", password: "x") == nil)
    }

    @Test("Signs in with the MediaBrowser header and reads the token")
    func signIn() async throws {
        ServerMockURLProtocol.handler = { request in
            #expect(request.url?.path == "/Users/AuthenticateByName")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization")?.contains(#"DeviceId="dev-1""#) == true)
            #expect(request.value(forHTTPHeaderField: "X-Emby-Authorization") != nil)
            return (200, Data(#"{"User":{"Id":"user-9"},"AccessToken":"abc"}"#.utf8))
        }
        let base = try #require(URL(string: "http://nas.local:8096"))
        let account = try await client().signIn(kind: .jellyfin, baseURL: base, username: "dad", password: "pw")
        #expect(account == MediaServerAccount(kind: .jellyfin, baseURL: base, userID: "user-9", token: "abc"))
    }

    @Test("A 401 at sign-in is a credentials error")
    func badCredentials() async throws {
        ServerMockURLProtocol.handler = { _ in (401, Data()) }
        let base = try #require(URL(string: "http://nas.local:8096"))
        await #expect(throws: MediaServerError.badCredentials) {
            try await client().signIn(kind: .emby, baseURL: base, username: "dad", password: "nope")
        }
    }

    @Test("Movies and episodes become HLS entries grouped by series")
    func library() async throws {
        ServerMockURLProtocol.handler = { request in
            #expect(request.url?.path == "/Users/user-9/Items")
            #expect(request.url?.query()?.contains("api_key=abc") == true)
            let body = #"""
            {"Items":[
              {"Id":"m1","Name":"Dune","Type":"Movie"},
              {"Id":"e1","Name":"Pilot","Type":"Episode","SeriesName":"The Road","ParentIndexNumber":1,"IndexNumber":2}
            ]}
            """#
            return (200, Data(body.utf8))
        }
        let base = try #require(URL(string: "http://nas.local:8096"))
        let account = MediaServerAccount(kind: .emby, baseURL: base, userID: "user-9", token: "abc")
        let entries = try await client().library(for: account)

        #expect(entries.map(\.name) == ["Dune", "S1 · E2 — Pilot"])
        #expect(entries.map(\.group) == ["Movies", "The Road"])
        let stream = try #require(entries.first?.streamURL)
        #expect(stream.path == "/Videos/m1/master.m3u8")
        #expect(stream.query()?.contains("MediaSourceId=m1") == true)
        #expect(stream.query()?.contains("api_key=abc") == true)
        #expect(entries.first?.logoURL?.path == "/Items/m1/Images/Primary")
    }
}

@Suite("Media server sources")
@MainActor
struct MediaServerRepositoryTests {
    @Test("Adding a server stores its library and keeps the token in the secure store")
    func add() async throws {
        let library = try TestLibrary()
        let id = try await library.repository.addMediaServer(
            kind: .jellyfin, name: "", address: "nas.local:8096", username: "dad", password: "pw"
        )
        let playlist = try #require(try library.repository.playlists().first)
        #expect(playlist.kind == .mediaServer)
        #expect(playlist.name == "Jellyfin · nas.local")
        #expect(try library.repository.items().map(\.title) == ["Dune", "S1 · E1 — Pilot"])
        let stored = try #require(try library.secureStore.string(for: "playlist.source.\(id.uuidString)"))
        #expect(stored.contains("\"token\":\"tok\""))
    }

    @Test("Wrong password adds nothing")
    func wrongPassword() async throws {
        let library = try TestLibrary()
        await #expect(throws: MediaServerError.badCredentials) {
            try await library.repository.addMediaServer(
                kind: .emby, name: "", address: "nas.local", username: "dad", password: "x"
            )
        }
        #expect(try library.repository.playlists().isEmpty)
    }

    @Test("Refreshing a server re-reads its library and keeps favourites")
    func refresh() async throws {
        let library = try TestLibrary()
        let id = try await library.repository.addMediaServer(
            kind: .jellyfin, name: "NAS", address: "nas.local", username: "dad", password: "pw"
        )
        let dune = try #require(try library.repository.items().first)
        try library.repository.toggleFavorite(dune.id)
        try library.mediaServer.setEntries(Fixtures.serverEntries + [
            PlaylistEntry(
                name: "Arrival",
                group: "Movies",
                logoURL: nil,
                streamURL: #require(URL(string: "http://nas.local/v/3.m3u8"))
            )
        ])

        try await library.repository.refresh(id)

        #expect(library.mediaServer.libraryCalls == 2)
        #expect(try library.repository.items().count == 3)
        #expect(try library.repository.favorites().map(\.title) == ["Dune"])
    }

    @Test("Xtream logins are added as a remote playlist")
    func xtream() async throws {
        let library = try TestLibrary()
        let url = try #require(XtreamLink.playlistURL(server: "panel.example.com", username: "me", password: "pw"))
        library.fetcher.stub(url, with: Fixtures.playlist)

        try await library.repository.addXtream(name: "", server: "panel.example.com", username: "me", password: "pw")

        let playlist = try #require(try library.repository.playlists().first)
        #expect(playlist.kind == .remote)
        #expect(playlist.name == "Xtream · panel.example.com")
        #expect(try library.repository.items().count == 4)
    }

    @Test("The free-limit count ignores the On this iPhone shelf")
    func sourceCount() async throws {
        let library = try TestLibrary()
        #expect(library.repository.sourceCount() == 0)
        let video = FileManager.default.temporaryDirectory.appending(path: "clip-\(UUID().uuidString).mov")
        try Data("x".utf8).write(to: video)
        defer { try? FileManager.default.removeItem(at: video) }
        try library.repository.importVideos([video])
        #expect(library.repository.sourceCount() == 0)
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        #expect(library.repository.sourceCount() == 1)
    }
}
