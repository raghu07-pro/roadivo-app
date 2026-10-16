import Foundation
import Testing
@testable import Roadivo

@Suite("Library repository")
@MainActor
struct LibraryRepositoryTests {
    @Test("Adding a link stores channels and keeps the full link in the secure store")
    func addRemote() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)

        let id = try await library.repository.addRemotePlaylist(name: "", url: Fixtures.playlistURL)

        let playlist = try #require(try library.repository.playlists().first)
        #expect(playlist.id == id)
        #expect(playlist.name == "iptv.example.com")
        #expect(playlist.sourceHost == "iptv.example.com")
        #expect(try library.repository.items().map(\.title) == [
            "News One",
            "News Two",
            "Football Live",
            "Untitled Movie"
        ])
        let stored = try library.secureStore.string(for: "playlist.source.\(id.uuidString)")
        #expect(stored == Fixtures.playlistURL.absoluteString)
    }

    @Test("A link to a single HLS stream becomes a one-item playlist")
    func addHLSStream() async throws {
        let library = try TestLibrary()
        let url = try #require(URL(string: "https://e.com/live/master.m3u8"))
        library.fetcher.stub(url, with: Fixtures.hlsStream)

        try await library.repository.addRemotePlaylist(name: "My Stream", url: url)

        let items = try library.repository.items()
        #expect(items.count == 1)
        #expect(items.first?.streamURL == url)
        #expect(items.first?.title == "My Stream")
    }

    @Test("Rejects non-http links and empty playlists")
    func rejects() async throws {
        let library = try TestLibrary()
        await #expect(throws: LibraryError.invalidURL) {
            try await library.repository.addRemotePlaylist(
                name: "",
                url: #require(URL(string: "ftp://e.com/a.m3u"))
            )
        }
        let empty = try #require(URL(string: "https://e.com/empty.m3u"))
        library.fetcher.stub(empty, with: "#EXTM3U\n")
        await #expect(throws: LibraryError.emptyPlaylist) {
            try await library.repository.addRemotePlaylist(name: "", url: empty)
        }
        #expect(try library.repository.playlists().isEmpty)
    }

    @Test("Refreshing keeps favourites for streams that are still listed")
    func refreshKeepsFavorites() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        let football = try #require(try library.repository.items().first { $0.title == "Football Live" })
        try library.repository.toggleFavorite(football.id)

        let updated = Fixtures.playlist + "\n#EXTINF:-1 group-title=\"Sports\",Tennis\nhttps://streams.example.com/tennis.m3u8"
        library.fetcher.stub(Fixtures.playlistURL, with: updated)
        try await library.repository.refresh(id)

        #expect(try library.repository.items().count == 5)
        #expect(try library.repository.favorites().map(\.title) == ["Football Live"])
    }

    @Test("Adding a link that returns a sign-in page fails and stores nothing")
    func addRejectsWebPage() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.signInPage)

        await #expect(throws: LibraryError.webPage) {
            try await library.repository.addRemotePlaylist(name: "", url: Fixtures.playlistURL)
        }
        #expect(try library.repository.playlists().isEmpty)
    }

    @Test("A sign-in page on refresh keeps every channel and favourite")
    func refreshRejectsWebPage() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        let football = try #require(try library.repository.items().first { $0.title == "Football Live" })
        try library.repository.toggleFavorite(football.id)

        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.signInPage)
        await #expect(throws: LibraryError.webPage) { try await library.repository.refresh(id) }

        #expect(try library.repository.items().map(\.title) == [
            "News One",
            "News Two",
            "Football Live",
            "Untitled Movie"
        ])
        #expect(try library.repository.favorites().map(\.title) == ["Football Live"])
    }

    @Test("Favourites, history, rename and deletion")
    func favoritesHistoryDelete() async throws {
        let library = try TestLibrary()
        let id = try await library.repository.addFilePlaylist(name: "File", text: Fixtures.playlist)
        let items = try library.repository.items()

        #expect(try library.repository.toggleFavorite(items[1].id))
        #expect(library.repository.isFavorite(items[1].id))
        library.repository.markPlayed(items[2].id, at: Date(timeIntervalSince1970: 10))
        library.repository.markPlayed(items[0].id, at: Date(timeIntervalSince1970: 20))
        #expect(try library.repository.recentlyPlayed().map(\.title) == ["News One", "Football Live"])

        try library.repository.rename(id, to: "  Renamed ")
        #expect(try library.repository.playlists().first?.name == "Renamed")

        try await library.repository.delete(id)
        #expect(try library.repository.playlists().isEmpty)
        #expect(try library.repository.items().isEmpty)
    }

    @Test("Imported videos land on the On this iPhone shelf")
    func importVideos() async throws {
        let library = try TestLibrary()
        let source = FileManager.default.temporaryDirectory.appending(path: "Beach Day.mp4")
        try Data("not really a video".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        #expect(try await library.repository.importVideos([source]) == 1)
        let local = try library.repository.localVideos()
        #expect(local.map(\.title) == ["Beach Day"])
        #expect(local.first?.isLocalFile == true)
        let storedPath = try #require(local.first).streamURL.path(percentEncoded: false)
        #expect(FileManager.default.fileExists(atPath: storedPath))

        let playlist = try #require(try library.repository.playlists().first)
        try await library.repository.delete(playlist.id)
        #expect(try library.repository.localVideos().isEmpty)
    }

    @Test("Adding a 20 000-channel playlist never blocks the main actor for long")
    func largePlaylistStaysOffMain() async throws {
        let library = try TestLibrary()
        let text = bigPlaylist(20000)

        let stall = try await longestMainActorStall {
            try await library.repository.addFilePlaylist(name: "Big", text: text)
        }

        #expect(try library.repository.items().count == 20000)
        #expect(stall < .seconds(1), "The main actor was blocked for \(stall)")
    }

    @Test("Items list sources in the order they were added, each in file order")
    func itemsKeepSourceOrder() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "First", text: bigPlaylist(3, host: "first.example.com"))
        try await library.repository.addFilePlaylist(name: "Second", text: Fixtures.playlist)
        let first = try #require(try library.repository.playlists().first)

        #expect(try library.repository.items().map(\.title) == [
            "Channel 0",
            "Channel 1",
            "Channel 2",
            "News One",
            "News Two",
            "Football Live",
            "Untitled Movie"
        ])
        #expect(try library.repository.items(in: first.id).count == 3)
    }

    @Test("Download failures surface as library errors")
    func downloadFailure() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, failing: .httpStatus(403))
        await #expect(throws: LibraryError.httpStatus(403)) {
            try await library.repository.addRemotePlaylist(name: "", url: Fixtures.playlistURL)
        }
    }

    @Test("Refresh keeps a stream listed twice favourited if either copy was, with its latest play")
    func refreshMergesDuplicateStreams() async throws {
        let library = try TestLibrary()
        let text = """
        #EXTM3U
        #EXTINF:-1,Sports HD
        https://streams.example.com/sports.m3u8
        #EXTINF:-1,Sports Backup
        https://streams.example.com/sports.m3u8
        #EXTINF:-1,News
        https://streams.example.com/news.m3u8
        """
        library.fetcher.stub(Fixtures.playlistURL, with: text)
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        let items = try library.repository.items()
        try library.repository.toggleFavorite(items[0].id)
        library.repository.markPlayed(items[0].id, at: Date(timeIntervalSince1970: 20))
        library.repository.markPlayed(items[1].id, at: Date(timeIntervalSince1970: 50))
        library.repository.markPlayed(items[2].id, at: Date(timeIntervalSince1970: 30))

        try await library.repository.refresh(id)

        #expect(try library.repository.favorites().map(\.title).sorted() == ["Sports Backup", "Sports HD"])
        let recent = try library.repository.recentlyPlayed()
        #expect(recent.count == 3)
        #expect(recent.last?.title == "News")
    }

    @Test("A source restored without its link says to add it again, and keeps its channels")
    func refreshWithoutSecret() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        try library.secureStore.removeAll()

        await #expect(throws: SourceSecretError.missing) { try await library.repository.refresh(id) }
        #expect(try library.repository.items().count == 4)
        #expect(library.fetcher.requested.count == 1)
    }

    @Test("Refreshing a deleted source is still reported as gone")
    func refreshDeletedSource() async throws {
        let library = try TestLibrary()
        await #expect(throws: LibraryError.notFound) { try await library.repository.refresh(UUID()) }
    }

    @Test("A source whose secret can't be saved leaves no row behind")
    func failedAddLeavesNothing() async throws {
        let store = try SwiftDataStore(inMemory: true)
        let fetcher = StubFetcher()
        fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        let secrets = RefusingSecureStore()
        let repository = LibraryRepository(
            store: store, secureStore: secrets, fetcher: fetcher, mediaServers: StubMediaServer()
        )

        await #expect(throws: KeychainError(status: -25291)) {
            try await repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        }
        #expect(try repository.playlists().isEmpty)
        #expect(try repository.items().isEmpty)
        #expect(secrets.removedKeys.count == 1)
    }

    @Test("Deleting a big source removes its channels and secret, and leaves other sources alone")
    func deleteBigSource() async throws {
        let library = try TestLibrary()
        let keep = try await library.repository.addFilePlaylist(name: "Keep", text: Fixtures.playlist)
        let url = try #require(URL(string: "https://big.example.com/list.m3u"))
        library.fetcher.stub(url, with: bigPlaylist(3000, host: "big.example.com"))
        let big = try await library.repository.addRemotePlaylist(name: "Big", url: url)
        #expect(try library.repository.channelCount(in: big) == 3000)

        try await library.repository.delete(big)

        #expect(try library.repository.playlists().map(\.id) == [keep])
        #expect(try library.repository.channelCount(in: big) == 0)
        #expect(try library.repository.channelCount(in: keep) == 4)
        #expect(try library.secureStore.string(for: "playlist.source.\(big.uuidString)") == nil)
    }

    @Test("Continue Watching can leave out imported videos inside the fetch, so it isn't cut short")
    func recentExcludingLocal() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let channel = try #require(try library.repository.items().first)
        let source = FileManager.default.temporaryDirectory.appending(path: "Dash \(UUID().uuidString).mp4")
        try Data("x".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        try await library.repository.importVideos([source])
        let video = try #require(try library.repository.localVideos().first)
        defer { try? library.repository.deleteVideo(video.id) } // Also removes the copied file.
        library.repository.markPlayed(channel.id, at: Date(timeIntervalSince1970: 1))
        library.repository.markPlayed(video.id, at: Date(timeIntervalSince1970: 10))

        #expect(try library.repository.recentlyPlayed(limit: 1).map(\.id) == [video.id])
        #expect(try library.repository.continueWatching(limit: 1).map(\.id) == [channel.id])
    }

    @Test("When no video copies, the copy's own error is shown, not \"couldn't be read as a playlist\"")
    func importReportsCopyError() async throws {
        let library = try TestLibrary()
        let missing = FileManager.default.temporaryDirectory.appending(path: "Gone \(UUID().uuidString).mp4")
        do {
            try await library.repository.importVideos([missing])
            Issue.record("Importing a missing file succeeded")
        } catch {
            #expect(!(error is LibraryError))
            #expect((error as? CocoaError)?.code == .fileReadNoSuchFile)
        }
        #expect(try library.repository.localVideos().isEmpty)
    }

    @Test("When only some videos copy, the count says how many were imported")
    func importReportsPartialCount() async throws {
        let library = try TestLibrary()
        let present = FileManager.default.temporaryDirectory.appending(path: "Here \(UUID().uuidString).mp4")
        let missing = FileManager.default.temporaryDirectory.appending(path: "Gone \(UUID().uuidString).mp4")
        try Data("x".utf8).write(to: present)
        defer { try? FileManager.default.removeItem(at: present) }

        #expect(try await library.repository.importVideos([present, missing]) == 1)
        let videos = try library.repository.localVideos()
        for video in videos {
            try library.repository.deleteVideo(video.id) // Also removes the copied file.
        }
        #expect(videos.count == 1)
    }
}

/// A Keychain that refuses every write (errSecNotAvailable), recording what was removed.
private final class RefusingSecureStore: SecureStore, @unchecked Sendable {
    private let lock = NSLock()
    private var removed: [String] = []

    var removedKeys: [String] {
        lock.withLock { removed }
    }

    func set(_ value: String, for key: String) throws {
        throw KeychainError(status: -25291)
    }

    func string(for key: String) throws -> String? {
        nil
    }

    func remove(_ key: String) throws {
        lock.withLock { removed.append(key) }
    }

    func removeAll() throws {}
}
