import Foundation
import SwiftData
import Testing
@testable import Roadivo

@Suite("Watch history")
@MainActor
struct WatchHistoryTests {
    private let halfway = PlaybackProgress(position: 1500, duration: 3600)

    private func item(_ title: String, in library: TestLibrary) throws -> MediaItem {
        try #require(try library.repository.items().first { $0.title == title })
    }

    @Test("A saved place comes back for the next play and shows as the item's progress")
    func savesPlace() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let movie = try item("Untitled Movie", in: library)

        library.repository.saveProgress(halfway, for: movie.id)

        #expect(library.repository.resumePosition(for: movie.id) == 1500)
        #expect(try item("Untitled Movie", in: library).progress == halfway)
    }

    @Test("A video watched to the end leaves Continue Watching but stays in Recent")
    func finishedLeavesContinueWatching() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let movie = try item("Untitled Movie", in: library)
        library.repository.markPlayed(movie.id)
        library.repository.saveProgress(halfway, for: movie.id)

        library.repository.saveProgress(PlaybackProgress(position: 3500, duration: 3600), for: movie.id)

        #expect(try library.repository.continueWatching().isEmpty)
        #expect(try library.repository.recentlyPlayed().map(\.id) == [movie.id])
        #expect(library.repository.resumePosition(for: movie.id) == nil)
        #expect(try item("Untitled Movie", in: library).progress == nil)
    }

    @Test("Playing a finished video again puts it back in Continue Watching")
    func replayReturns() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let movie = try item("Untitled Movie", in: library)
        library.repository.markPlayed(movie.id)
        library.repository.saveProgress(PlaybackProgress(position: 3600, duration: 3600), for: movie.id)

        library.repository.markPlayed(movie.id)

        #expect(try library.repository.continueWatching().map(\.id) == [movie.id])
    }

    @Test("Removing an item from Continue Watching forgets its play and its place")
    func removeFromHistory() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let movie = try item("Untitled Movie", in: library)
        let news = try item("News One", in: library)
        library.repository.markPlayed(news.id, at: Date(timeIntervalSince1970: 1))
        library.repository.markPlayed(movie.id, at: Date(timeIntervalSince1970: 2))
        library.repository.saveProgress(halfway, for: movie.id)

        try library.repository.removeFromHistory(movie.id)

        #expect(try library.repository.continueWatching().map(\.id) == [news.id])
        #expect(try library.repository.recentlyPlayed().map(\.id) == [news.id])
        #expect(library.repository.resumePosition(for: movie.id) == nil)
        #expect(try item("Untitled Movie", in: library).progress == nil)
    }

    @Test("Removing an item that's gone says so, and saving its place does nothing")
    func missingItem() throws {
        let library = try TestLibrary()
        #expect(throws: LibraryError.notFound) { try library.repository.removeFromHistory(UUID()) }
        library.repository.saveProgress(halfway, for: UUID())
        #expect(library.repository.resumePosition(for: UUID()) == nil)
    }

    @Test("Refreshing keeps each stream's play and place")
    func refreshKeepsPlace() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        let movie = try item("Untitled Movie", in: library)
        library.repository.markPlayed(movie.id)
        library.repository.saveProgress(halfway, for: movie.id)

        try await library.repository.refresh(id)

        let refreshed = try item("Untitled Movie", in: library)
        #expect(refreshed.id != movie.id)
        #expect(refreshed.progress == halfway)
        #expect(library.repository.resumePosition(for: refreshed.id) == 1500)
        #expect(try library.repository.continueWatching().map(\.id) == [refreshed.id])
    }

    @Test("When every link changes (a new login token), each stream keeps its favourite, play and place")
    func refreshFollowsChangedLinks() async throws {
        let library = try TestLibrary()
        let playlist = { (token: String) in
            """
            #EXTM3U
            #EXTINF:-1 group-title="Sports",Football Live
            https://streams.example.com/football.m3u8?token=\(token)
            #EXTINF:0 group-title="Films",Road Movie
            https://vod.example.com/road.mp4?token=\(token)
            """
        }
        library.fetcher.stub(Fixtures.playlistURL, with: playlist("first"))
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        let football = try item("Football Live", in: library)
        let film = try item("Road Movie", in: library)
        try library.repository.toggleFavorite(football.id)
        library.repository.markPlayed(football.id, at: Date(timeIntervalSince1970: 1))
        library.repository.markPlayed(film.id, at: Date(timeIntervalSince1970: 2))
        library.repository.saveProgress(halfway, for: film.id)

        library.fetcher.stub(Fixtures.playlistURL, with: playlist("second"))
        try await library.repository.refresh(id)

        #expect(try library.repository.favorites().map(\.title) == ["Football Live"])
        #expect(try library.repository.continueWatching().map(\.title) == ["Road Movie", "Football Live"])
        #expect(try item("Road Movie", in: library).progress == halfway)
    }

    @Test("A place kept while a refresh rewrites the source doesn't make the refresh fail")
    func saveDuringRefresh() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let movie = try item("Untitled Movie", in: library)
        // A refresh reads the old rows in its own context…
        let writer = ModelContext(library.store.container)
        let old = try writer.fetch(FetchDescriptor<Channel>())
        // …the player keeps its place from the main context…
        library.repository.saveProgress(halfway, for: movie.id)
        // …and the refresh then deletes the rows and saves.
        old.forEach(writer.delete)
        try writer.save()

        #expect(try library.repository.items().isEmpty)
    }

    @Test("Same-named streams whose links all changed each keep their own favourite and play")
    func sameNamedStreamsPairInOrder() async throws {
        let library = try TestLibrary()
        let playlist = { (token: String) in
            """
            #EXTM3U
            #EXTINF:-1 group-title="Sports",Sky Sports
            https://streams.example.com/sky-hd.m3u8?token=\(token)
            #EXTINF:-1 group-title="Sports",Sky Sports
            https://backup.example.com/sky.m3u8?token=\(token)
            """
        }
        library.fetcher.stub(Fixtures.playlistURL, with: playlist("first"))
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        let first = try #require(try library.repository.items().first)
        try library.repository.toggleFavorite(first.id)
        library.repository.markPlayed(first.id)

        library.fetcher.stub(Fixtures.playlistURL, with: playlist("second"))
        try await library.repository.refresh(id)

        #expect(try library.repository.favorites().map { $0.streamURL.host() } == ["streams.example.com"])
        #expect(try library.repository.recentlyPlayed().map { $0.streamURL.host() } == ["streams.example.com"])
    }

    @Test("A new stream under a title whose link is still listed doesn't inherit its history")
    func backupStreamStartsClean() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        let news = try item("News One", in: library)
        try library.repository.toggleFavorite(news.id)
        library.repository.markPlayed(news.id)

        let withBackup = Fixtures.playlist + """

        #EXTINF:-1 group-title="News",News One
        https://backup.example.com/news1.m3u8
        """
        library.fetcher.stub(Fixtures.playlistURL, with: withBackup)
        try await library.repository.refresh(id)

        #expect(try library.repository.favorites().map { $0.streamURL.host() } == ["streams.example.com"])
        #expect(try library.repository.recentlyPlayed().count == 1)
    }

    @Test("A server's films keep their place when its address changes, with remakes told apart by year")
    func serverAddressChange() async throws {
        let library = try TestLibrary()
        let films = { (host: String) throws -> [PlaylistEntry] in
            try [(1, 1984), (2, 2021)].map { number, year in
                try PlaylistEntry(
                    name: "Dune",
                    group: "Movies",
                    logoURL: nil,
                    streamURL: #require(URL(string: "http://\(host)/v/\(number).m3u8?api_key=tok")),
                    year: year
                )
            }
        }
        try library.mediaServer.setEntries(films("nas.local:8096"))
        let id = try await library.repository.addMediaServer(
            kind: .jellyfin, name: "", address: "nas.local:8096", username: "dad", password: "pw"
        )
        let remake = try #require(try library.repository.items().first { $0.year == 2021 })
        library.repository.markPlayed(remake.id)
        library.repository.saveProgress(halfway, for: remake.id)

        try library.mediaServer.setEntries(films("192.168.1.20:8096"))
        try await library.repository.refresh(id)

        let items = try library.repository.items()
        #expect(items.first { $0.year == 2021 }?.progress == halfway)
        #expect(items.first { $0.year == 1984 }?.progress == nil)
        #expect(try library.repository.continueWatching().map(\.year) == [2021])
    }
}
