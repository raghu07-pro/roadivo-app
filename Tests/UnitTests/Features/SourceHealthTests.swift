import Foundation
import Testing
@testable import Roadivo

/// Answers each request with a status and content type, or an error.
final class HealthMockURLProtocol: URLProtocol, @unchecked Sendable {
    enum Answer {
        case status(Int, mimeType: String)
        case error(URLError.Code)
    }

    nonisolated(unsafe) static var answer: Answer = .status(200, mimeType: "video/mp2t")

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else { return }
        switch Self.answer {
        case let .status(code, mimeType):
            let headers = ["Content-Type": mimeType]
            if let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: headers) {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            client?.urlProtocol(self, didLoad: Data(repeating: 0, count: 64))
            client?.urlProtocolDidFinishLoading(self)
        case let .error(code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        }
    }

    override func stopLoading() {}
}

/// Answers from a table by URL and counts how many probes ran at once.
private final class TableProbe: StreamProbing, @unchecked Sendable {
    private let lock = NSLock()
    private let outcomes: [URL: StreamOutcome]
    private var inFlight = 0
    private(set) var mostAtOnce = 0
    private(set) var probed: [URL] = []

    init(_ outcomes: [URL: StreamOutcome]) {
        self.outcomes = outcomes
    }

    func probe(_ url: URL) async -> StreamOutcome {
        lock.withLock {
            inFlight += 1
            mostAtOnce = max(mostAtOnce, inFlight)
            probed.append(url)
        }
        try? await Task.sleep(for: .milliseconds(20)) // Lets probes overlap, to measure them.
        lock.withLock { inFlight -= 1 }
        return outcomes[url] ?? .working(milliseconds: 100)
    }
}

@MainActor
private final class Seen {
    var ids: [UUID] = []
}

@Suite("Source Health", .serialized)
@MainActor
struct SourceHealthTests {
    private let mixedPlaylist = """
    #EXTM3U
    #EXTINF:-1 group-title="News",Good One
    https://streams.example.com/good1.m3u8
    #EXTINF:-1 group-title="News",No Link
    #EXTINF:-1 group-title="News",Multicast
    udp://239.0.0.1:1234
    a stray line that isn't an entry
    #EXTINF:-1 group-title="Sports",Good Two
    https://streams.example.com/good2.m3u8
    #EXTINF:-1 group-title="Sports",Dangling
    """

    private func probe() -> StreamProbe {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HealthMockURLProtocol.self]
        return StreamProbe(session: URLSession(configuration: configuration))
    }

    private func url(_ path: String) throws -> URL {
        try #require(URL(string: "https://streams.example.com/\(path)"))
    }

    // MARK: Reading the playlist

    @Test("The parser reports entries with no link and links Roadivo can't play, not stray text")
    func parseIssues() {
        let report = M3UParser.report(mixedPlaylist)

        #expect(report.entries.map(\.name) == ["Good One", "Good Two"])
        #expect(report.issues == M3UParser.Issues(withoutLink: 2, unsupportedLink: 1))
        #expect(report.issues.total == 3)
    }

    @Test("Adding a pasted list keeps what couldn't be read, for Source Health")
    func issuesAreKept() async throws {
        let library = try TestLibrary()
        let id = try await library.repository.addFilePlaylist(name: "Mixed", text: mixedPlaylist)

        let health = try library.repository.health(of: id)

        #expect(health.issues == M3UParser.Issues(withoutLink: 2, unsupportedLink: 1))
        #expect(health.channelCount == 2)
        #expect(!health.refreshFailed)
    }

    @Test("A failed refresh is kept with its reason, and the next good one clears it")
    func refreshOutcome() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        library.fetcher.stub(Fixtures.playlistURL, failing: .httpStatus(500))

        await #expect(throws: (any Error).self) { try await library.repository.refresh(id) }
        let failed = try library.repository.health(of: id)
        #expect(failed.refreshFailed)
        #expect(failed.lastRefreshAttemptAt != nil)

        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        try await library.repository.refresh(id)
        let fixed = try library.repository.health(of: id)
        #expect(!fixed.refreshFailed)
        #expect(fixed.issues == M3UParser.Issues())
    }

    // MARK: Probing one stream

    @Test("A stream that answers is working; a missing, refused or web-page answer says why")
    func probeOutcomes() async throws {
        let stream = try url("live.ts")

        HealthMockURLProtocol.answer = .status(200, mimeType: "video/mp2t")
        guard case .working = await probe().probe(stream) else {
            Issue.record("Expected a working stream")
            return
        }
        HealthMockURLProtocol.answer = .status(404, mimeType: "text/plain")
        #expect(await probe().probe(stream) == .failed(.notFound))
        HealthMockURLProtocol.answer = .status(403, mimeType: "text/plain")
        #expect(await probe().probe(stream) == .failed(.denied(403)))
        HealthMockURLProtocol.answer = .status(503, mimeType: "text/plain")
        #expect(await probe().probe(stream) == .failed(.serverError(503)))
        HealthMockURLProtocol.answer = .status(200, mimeType: "text/html")
        #expect(await probe().probe(stream) == .failed(.webPage))
        HealthMockURLProtocol.answer = .error(.timedOut)
        #expect(await probe().probe(stream) == .failed(.timedOut))
        HealthMockURLProtocol.answer = .error(.cannotFindHost)
        #expect(await probe().probe(stream) == .failed(.noServer))
        HealthMockURLProtocol.answer = .error(.notConnectedToInternet)
        #expect(await probe().probe(stream) == .failed(.offline))
    }

    @Test("rtmp and rtsp links aren't opened, and count neither way")
    func unsupportedSchemes() async throws {
        let rtmp = try #require(URL(string: "rtmp://live.example.com/app/stream"))
        #expect(await probe().probe(rtmp) == .unchecked)
    }

    // MARK: Checking many

    @Test("The check reaches every stream but never opens more than two at once")
    func concurrencyLimit() async throws {
        let urls = try (0..<9).map { try url("s\($0).m3u8") }
        let table = TableProbe([:])
        let checker = StreamChecker(probe: table, concurrency: 2)
        let seen = Seen()

        await checker.check(urls.map { StreamTarget(id: UUID(), url: $0) }) { target, _ in
            seen.ids.append(target.id)
        }

        #expect(seen.ids.count == 9)
        #expect(Set(table.probed) == Set(urls))
        #expect(table.mostAtOnce <= 2)
    }

    @Test("Failed streams are listed before slow ones, and working ones not at all")
    func problemOrder() {
        func item(_ title: String) -> MediaItem {
            MediaItem(
                id: UUID(),
                title: title,
                group: "News",
                artworkURL: nil,
                streamURL: URL(fileURLWithPath: "/dev/null/\(title)"),
                isLocalFile: false,
                isFavorite: false
            )
        }
        var report = StreamCheckReport(checkedAt: .now, total: 4)
        report.record(item("Slow"), .slow(milliseconds: 4000))
        report.record(item("Fine"), .working(milliseconds: 90))
        report.record(item("Gone"), .failed(.notFound))
        report.record(item("Odd"), .unchecked)

        #expect(report.problems.map(\.title) == ["Gone", "Slow"])
        #expect((report.working, report.slow, report.failed, report.unchecked) == (1, 1, 1, 1))
        #expect(report.checked == 3)
        #expect(report.answered == 2)
    }

    // MARK: The screen

    @Test("Checking a source's streams counts each outcome, saves the report and shows it on the row")
    func checkAndSave() async throws {
        let library = try TestLibrary()
        let id = try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let broken = try #require(URL(string: "https://streams.example.com/news2.m3u8"))
        let checker = StreamChecker(probe: TableProbe([broken: .failed(.notFound)]))
        let sources = SourcesViewModel(repository: library.repository, checker: checker)
        sources.load()
        let health = try sources.health(for: #require(sources.sources.first))
        health.load()
        #expect(health.status == .unchecked)

        health.checkStreams()
        while health.isChecking {
            await Task.yield()
        }

        let report = try #require(health.report)
        #expect((report.working, report.failed, report.total) == (3, 1, 4))
        #expect(report.isComplete)
        #expect(report.problems.map(\.title) == ["News Two"])
        #expect(health.status == .attention)
        #expect(try library.repository.health(of: id).streamCheck == report)

        sources.load()
        #expect(sources.sources.first?.streamsAnswered == 3)
        #expect(sources.sources.first?.streamsChecked == 4)
    }

    @Test("Mostly failing streams read as not working")
    func mostlyFailing() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let gone = StreamOutcome.failed(.timedOut)
        let urls = ["news1", "news2", "football"].compactMap { URL(string: "https://streams.example.com/\($0).m3u8") }
        let checker = StreamChecker(probe: TableProbe(Dictionary(uniqueKeysWithValues: urls.map { ($0, gone) })))
        let sources = SourcesViewModel(repository: library.repository, checker: checker)
        sources.load()
        let health = try sources.health(for: #require(sources.sources.first))
        health.load()

        health.checkStreams()
        while health.isChecking {
            await Task.yield()
        }

        #expect(health.status == .failing)
    }

    @Test("Going offline stops the check and keeps the last saved one")
    func offlineStops() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let urls = ["news1", "news2", "football"].compactMap { URL(string: "https://streams.example.com/\($0).m3u8") }
        let offline = Dictionary(uniqueKeysWithValues: urls.map { ($0, StreamOutcome.failed(.offline)) })
        let sources = SourcesViewModel(
            repository: library.repository,
            checker: StreamChecker(probe: TableProbe(offline))
        )
        sources.load()
        let health = try sources.health(for: #require(sources.sources.first))
        health.load()

        health.checkStreams()
        while health.isChecking {
            await Task.yield()
        }

        #expect(health.errorMessage == StreamProblem.offline.description)
        #expect(health.report == nil)
    }

    @Test("A failed refresh shows on the Manage Sources row")
    func rowShowsFailedRefresh() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        library.fetcher.stub(Fixtures.playlistURL, failing: .httpStatus(500))
        let sources = SourcesViewModel(repository: library.repository)

        #expect(await !sources.refresh(id))
        sources.load()

        #expect(sources.sources.first?.refreshFailed == true)
    }

    @Test("A media server is checked at its public status page, never per video")
    func serverCheckURL() async throws {
        let library = try TestLibrary()
        let id = try await library.repository.addMediaServer(
            kind: .jellyfin, name: "", address: "nas.local:8096", username: "dad", password: "pw"
        )

        let url = try #require(library.repository.serverCheckURL(for: id))

        #expect(url.absoluteString == "http://nas.local:8096/System/Info/Public")
    }
}
