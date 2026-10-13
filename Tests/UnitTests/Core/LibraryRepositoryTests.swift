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

        try library.repository.delete(id)
        #expect(try library.repository.playlists().isEmpty)
        #expect(try library.repository.items().isEmpty)
    }

    @Test("Imported videos land on the On this iPhone shelf")
    func importVideos() throws {
        let library = try TestLibrary()
        let source = FileManager.default.temporaryDirectory.appending(path: "Beach Day.mp4")
        try Data("not really a video".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        #expect(try library.repository.importVideos([source]) == 1)
        let local = try library.repository.localVideos()
        #expect(local.map(\.title) == ["Beach Day"])
        #expect(local.first?.isLocalFile == true)
        let storedPath = try #require(local.first).streamURL.path(percentEncoded: false)
        #expect(FileManager.default.fileExists(atPath: storedPath))

        let playlist = try #require(try library.repository.playlists().first)
        try library.repository.delete(playlist.id)
        #expect(try library.repository.localVideos().isEmpty)
    }

    @Test("Download failures surface as library errors")
    func downloadFailure() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, failing: .httpStatus(403))
        await #expect(throws: LibraryError.httpStatus(403)) {
            try await library.repository.addRemotePlaylist(name: "", url: Fixtures.playlistURL)
        }
    }
}
