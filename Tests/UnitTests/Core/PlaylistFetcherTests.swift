import Foundation
import Testing
@testable import Roadivo

/// Serves a canned response per URL, in chunks, so the fetcher's streaming
/// limits are exercised without a network. Keyed by URL so suites running in
/// parallel never see each other's responses.
final class PlaylistURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response {
        var status = 200
        var headers: [String: String] = [:]
        var chunks: [Data]
    }

    private static let lock = NSLock()
    nonisolated(unsafe) static var responses: [URL: Response] = [:]

    static func serve(_ url: URL, _ response: Response) {
        lock.withLock { responses[url] = response }
    }

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let canned = Self.lock.withLock({ Self.responses[url] }),
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: canned.status,
                  httpVersion: "HTTP/1.1",
                  headerFields: canned.headers
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for chunk in canned.chunks {
            client?.urlProtocol(self, didLoad: chunk)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("Playlist fetcher")
struct PlaylistFetcherTests {
    private func fetcher(maximumBytes: Int = 100 * 1024 * 1024) -> URLSessionPlaylistFetcher {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PlaylistURLProtocol.self]
        return URLSessionPlaylistFetcher(session: URLSession(configuration: configuration), maximumBytes: maximumBytes)
    }

    private func uniqueURL(_ name: String) throws -> URL {
        try #require(URL(string: "https://iptv.example.com/\(UUID().uuidString)/\(name)"))
    }

    @Test("Downloads a playlist as text")
    func downloadsText() async throws {
        let url = try uniqueURL("list.m3u")
        PlaylistURLProtocol.serve(url, .init(chunks: [Data(Fixtures.playlist.utf8)]))
        #expect(try await fetcher().fetchText(from: url) == Fixtures.playlist)
    }

    @Test("Stops reading once the body passes the size limit")
    func stopsAtLimit() async throws {
        let url = try uniqueURL("endless.m3u")
        let line = Data("#EXTINF:-1,Channel\nhttps://e.com/live.m3u8\n".utf8)
        PlaylistURLProtocol.serve(url, .init(chunks: Array(repeating: line, count: 200)))
        await #expect(throws: LibraryError.tooLarge) {
            try await fetcher(maximumBytes: 1000).fetchText(from: url)
        }
    }

    @Test("Refuses a declared size over the limit before reading the body")
    func refusesDeclaredSize() async throws {
        let url = try uniqueURL("huge.m3u")
        PlaylistURLProtocol.serve(url, .init(headers: ["Content-Length": "5000"], chunks: [Data(count: 5000)]))
        await #expect(throws: LibraryError.tooLarge) {
            try await fetcher(maximumBytes: 1000).fetchText(from: url)
        }
    }

    @Test("A video link is recognised at once, not downloaded")
    func recognisesVideo() async throws {
        let url = try uniqueURL("live/me/pw/123.ts")
        // An MPEG-TS packet: sync byte, then binary header fields with zero bytes.
        let packet = Data([0x47, 0x40, 0x00, 0x10, 0x00, 0x00, 0xB0, 0x0D] + Array(repeating: 0xFF, count: 180))
        PlaylistURLProtocol.serve(url, .init(chunks: Array(repeating: packet, count: 50)))
        await #expect(throws: LibraryError.mediaFile) {
            try await fetcher().fetchText(from: url)
        }
    }

    @Test("A non-2xx status is an http error")
    func httpStatus() async throws {
        let url = try uniqueURL("gone.m3u")
        PlaylistURLProtocol.serve(url, .init(status: 404, chunks: [Data("Not found".utf8)]))
        await #expect(throws: LibraryError.httpStatus(404)) {
            try await fetcher().fetchText(from: url)
        }
    }
}
