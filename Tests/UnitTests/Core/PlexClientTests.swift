import Foundation
import Testing
@testable import Roadivo

/// Answers Plex requests by URL; its own class, so it never races the other server tests.
final class PlexMockURLProtocol: URLProtocol, @unchecked Sendable {
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
        if status == 0 {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        if let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("Plex", .serialized)
struct PlexClientTests {
    private func client() -> PlexClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PlexMockURLProtocol.self]
        return PlexClient(session: URLSession(configuration: configuration), clientID: "dev-1")
    }

    @Test("A short code is requested from plex.tv with the app's identity")
    func createPin() async throws {
        PlexMockURLProtocol.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://plex.tv/api/v2/pins?strong=false")
            #expect(request.value(forHTTPHeaderField: "X-Plex-Client-Identifier") == "dev-1")
            #expect(request.value(forHTTPHeaderField: "X-Plex-Product") == "Roadivo")
            return (201, Data(#"{"id":42,"code":"ABCD","expiresIn":900,"authToken":null}"#.utf8))
        }
        let pin = try await client().createPin()
        #expect(pin.id == 42)
        #expect(pin.code == "ABCD")
        #expect(abs(pin.expiresAt.timeIntervalSinceNow - 900) < 5)
    }

    @Test("Polling gives nil until the code is entered, then the token; an unknown code has expired")
    func pollToken() async throws {
        let pin = PlexPin(id: 42, code: "ABCD", expiresAt: .distantFuture)
        PlexMockURLProtocol.handler = { _ in (200, Data(#"{"id":42,"code":"ABCD","authToken":null}"#.utf8)) }
        #expect(try await client().token(for: pin) == nil)
        PlexMockURLProtocol.handler = { request in
            #expect(request.url?.path() == "/api/v2/pins/42")
            return (200, Data(#"{"id":42,"code":"ABCD","authToken":"user-token"}"#.utf8))
        }
        #expect(try await client().token(for: pin) == "user-token")
        PlexMockURLProtocol.handler = { _ in (404, Data()) }
        await #expect(throws: PlexError.codeExpired) { try await client().token(for: pin) }
    }

    @Test("Only servers are listed, each with its own token and addresses")
    func servers() async throws {
        PlexMockURLProtocol.handler = { request in
            #expect(request.url?.host() == "clients.plex.tv")
            #expect(request.value(forHTTPHeaderField: "X-Plex-Token") == "user-token")
            return (200, Data("""
            [{"name":"Living Room","provides":"server","owned":true,"accessToken":"srv-token","clientIdentifier":"m1",
              "connections":[{"uri":"https://10-0-0-2.m1.plex.direct:32400","local":true,"relay":false}]},
             {"name":"iPhone","provides":"client,player","clientIdentifier":"c1","connections":[]}]
            """.utf8))
        }
        let servers = try await client().servers(token: "user-token")
        #expect(servers.map(\.name) == ["Living Room"])
        #expect(servers.first?.accessToken == "srv-token")
        #expect(servers.first?.isOwned == true)
        #expect(servers.first?.connections.first?.isLocal == true)

        PlexMockURLProtocol.handler = { _ in (200, Data("[]".utf8)) }
        await #expect(throws: PlexError.noServers) { try await client().servers(token: "user-token") }
    }

    @Test("The first address that answers wins: local HTTPS before remote, relay last")
    func connectionChoice() async throws {
        let relay = try PlexConnection(
            uri: #require(URL(string: "https://relay.plex.direct")),
            isLocal: false,
            isRelay: true
        )
        let remote = try PlexConnection(
            uri: #require(URL(string: "https://remote.plex.direct")),
            isLocal: false,
            isRelay: false
        )
        let local = try PlexConnection(
            uri: #require(URL(string: "https://local.plex.direct")),
            isLocal: true,
            isRelay: false
        )
        let server = PlexServer(
            id: "m1",
            name: "Den",
            isOwned: true,
            accessToken: "srv",
            connections: [relay, remote, local]
        )
        // The local address is down, so the remote one should be chosen over the relay.
        PlexMockURLProtocol.handler = { request in
            request.url?.host() == "local.plex.direct" ? (0, Data()) : (200, Data("{}".utf8))
        }
        let account = try await client().account(for: server)
        #expect(account.baseURL.host() == "remote.plex.direct")
        #expect(account.kind == .plex)
        #expect(account.token == "srv")

        PlexMockURLProtocol.handler = { _ in (0, Data()) }
        await #expect(throws: PlexError.serverUnreachable) { try await client().account(for: server) }
    }

    @Test("Movies and episodes become channels: MP4 plays directly, the rest through HLS")
    func library() async throws {
        let account = try MediaServerAccount(
            kind: .plex,
            baseURL: #require(URL(string: "https://srv.plex.direct:32400")),
            userID: "m1",
            token: "srv"
        )
        PlexMockURLProtocol.handler = { request in
            let path = request.url?.path() ?? ""
            #expect(request.value(forHTTPHeaderField: "X-Plex-Token") == "srv")
            switch path {
            case "/library/sections":
                return (200, Data("""
                {"MediaContainer":{"Directory":[{"key":"1","title":"Films","type":"movie"},
                {"key":"2","title":"TV","type":"show"},{"key":"3","title":"Music","type":"artist"}]}}
                """.utf8))
            case "/library/sections/1/all":
                return (200, Data("""
                {"MediaContainer":{"totalSize":2,"Metadata":[
                {"ratingKey":"10","title":"Road Movie","type":"movie","thumb":"/library/metadata/10/thumb/1",
                 "Media":[{"container":"mp4","Part":[{"key":"/library/parts/5/1/file.mp4","container":"mp4"}]}]},
                {"ratingKey":"11","title":"Night Drive","type":"movie",
                 "Media":[{"container":"mkv","Part":[{"key":"/library/parts/6/1/file.mkv","container":"mkv"}]}]}]}}
                """.utf8))
            case "/library/sections/2/all":
                return (200, Data("""
                {"MediaContainer":{"totalSize":1,"Metadata":[
                {"ratingKey":"20","title":"Pilot","type":"episode","grandparentTitle":"Highway Show",
                 "parentIndex":1,"index":1,"Media":[{"container":"mp4","Part":[{"key":"/library/parts/7/1/e.mp4"}]}]}]}}
                """.utf8))
            default:
                Issue.record("Unexpected request \(path)")
                return (404, Data())
            }
        }
        let entries = try await client().library(for: account)
        #expect(entries.map(\.name) == ["Road Movie", "Night Drive", "S1 · E1 — Pilot"])
        #expect(entries.map(\.group) == ["Films", "Films", "Highway Show"])

        let direct = try #require(entries.first?.streamURL.absoluteString)
        #expect(direct == "https://srv.plex.direct:32400/library/parts/5/1/file.mp4?X-Plex-Token=srv")

        let transcoded = try #require(URLComponents(url: entries[1].streamURL, resolvingAgainstBaseURL: false))
        #expect(transcoded.path == "/video/:/transcode/universal/start.m3u8")
        let query = Dictionary(uniqueKeysWithValues: (transcoded.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(query["path"] == "/library/metadata/11")
        #expect(query["protocol"] == "hls")
        #expect(query["X-Plex-Token"] == "srv")

        let poster = try #require(entries.first?.logoURL)
        #expect(poster.path() == "/photo/:/transcode")
    }
}
