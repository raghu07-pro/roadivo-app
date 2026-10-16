import AVFoundation
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
    /// What the server calls itself.
    var serverName: String?

    init(entries: [PlaylistEntry] = Fixtures.serverEntries) {
        self.entries = entries
    }

    func setEntries(_ new: [PlaylistEntry]) {
        lock.withLock { entries = new }
    }

    func signIn(kind: MediaServerKind, baseURL: URL, username: String, password: String) async throws
        -> MediaServerAccount {
        guard password == "pw" else { throw MediaServerError.badCredentials }
        return MediaServerAccount(kind: kind, baseURL: baseURL, userID: "u1", token: "tok", serverName: serverName)
    }

    func library(for account: MediaServerAccount) async throws -> [PlaylistEntry] {
        lock.withLock {
            libraryCalls += 1
            return entries
        }
    }
}

/// Measures the longest stretch the main actor was blocked while `work` ran,
/// using a 5 ms heartbeat. A frozen UI shows up as one long gap.
@MainActor
func longestMainActorStall(during work: () async throws -> Void) async throws -> Duration {
    @MainActor
    final class Gap {
        var longest: Duration = .zero
    }
    let clock = ContinuousClock()
    let gap = Gap()
    let heartbeat = Task { @MainActor in
        var last = clock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(5))
            gap.longest = max(gap.longest, clock.now - last)
            last = clock.now
        }
    }
    defer { heartbeat.cancel() }
    try await Task.sleep(for: .milliseconds(20))
    try await work()
    return gap.longest
}

/// An extended M3U with `count` channels spread over 40 groups.
func bigPlaylist(_ count: Int, host: String = "s.example.com") -> String {
    "#EXTM3U\n" + (0..<count).map {
        "#EXTINF:-1 group-title=\"Group \($0 % 40)\",Channel \($0)\nhttps://\(host)/\($0).m3u8"
    }.joined(separator: "\n")
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

    /// What hotel Wi-Fi or an expired provider account sends back with a 200.
    static let signInPage = """
    <!DOCTYPE html>
    <html>
    <head><title>Sign in</title></head>
    <body>
    Welcome
    Please sign in to continue
    <a href="/login">Login</a>
    </body>
    </html>
    """
}

/// Writes a solid-orange 160×90 H.264 movie `seconds` long, `fps` frames a second, to a temporary file.
func makeTestMovie(seconds: Int, fps: Int32 = 30) async throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "movie-\(UUID().uuidString).mov")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 160, AVVideoHeightKey: 90
    ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: 160, kCVPixelBufferHeightKey as String: 90
    ])
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    for frame in 0..<(seconds * Int(fps)) {
        while !input.isReadyForMoreMediaData {
            try await Task.sleep(for: .milliseconds(5))
        }
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 160, 90, kCVPixelFormatType_32BGRA, nil, &buffer)
        guard let pixels = buffer else { throw CocoaError(.fileWriteUnknown) }
        CVPixelBufferLockBaseAddress(pixels, [])
        guard let base = CVPixelBufferGetBaseAddress(pixels)?.assumingMemoryBound(to: UInt8.self) else {
            throw CocoaError(.fileWriteUnknown)
        }
        for index in stride(from: 0, to: CVPixelBufferGetDataSize(pixels), by: 4) {
            base[index] = 0x20
            base[index + 1] = 0x90
            base[index + 2] = 0xFF
            base[index + 3] = 0xFF
        }
        CVPixelBufferUnlockBaseAddress(pixels, [])
        adaptor.append(pixels, withPresentationTime: CMTime(value: Int64(frame), timescale: fps))
    }
    input.markAsFinished()
    writer.endSession(atSourceTime: CMTime(value: Int64(seconds), timescale: 1))
    await writer.finishWriting()
    return url
}
