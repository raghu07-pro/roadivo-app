import Foundation
import Testing
@testable import PlayCarTV

/// Browsing like the reference app: Home's source filter, group chips, a source's own screen,
/// and server films as posters.
@Suite("Browse")
@MainActor
struct BrowseTests {
    private let secondPlaylist = """
    #EXTM3U
    #EXTINF:-1 group-title="Kids",Cartoon Hour
    https://streams.example.com/cartoons.m3u8
    #EXTINF:-1 group-title="Kids",Story Time
    https://streams.example.com/stories.m3u8
    """

    // MARK: Home's source filter

    @Test("Home lists each source with its channel count")
    func sourceOptions() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        try await library.repository.addFilePlaylist(name: "Kids", text: secondPlaylist)
        let viewModel = LibraryViewModel(repository: library.repository, scope: .all)

        viewModel.load()

        #expect(viewModel.sources.map(\.name) == ["TV", "Kids"])
        #expect(viewModel.sources.map(\.count) == [4, 2])
        #expect(viewModel.sourceFilter == nil)
        #expect(viewModel.items.count == 6)
    }

    @Test("Choosing a source shows only its channels and Continue Watching")
    func showOneSource() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let kids = try await library.repository.addFilePlaylist(name: "Kids", text: secondPlaylist)
        let viewModel = LibraryViewModel(repository: library.repository, scope: .all)
        viewModel.load()
        let football = try #require(viewModel.items.first { $0.title == "Football Live" })
        library.repository.markPlayed(football.id)

        viewModel.showSource(kids)

        #expect(viewModel.items.map(\.title) == ["Cartoon Hour", "Story Time"])
        #expect(viewModel.sections.map(\.title) == ["Kids"])
        #expect(viewModel.recent.isEmpty)

        viewModel.showSource(nil)
        #expect(viewModel.items.count == 6)
        #expect(viewModel.recent.map(\.title) == ["Football Live"])
    }

    @Test("Deleting the chosen source goes back to all sources")
    func chosenSourceDeleted() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let kids = try await library.repository.addFilePlaylist(name: "Kids", text: secondPlaylist)
        let viewModel = LibraryViewModel(repository: library.repository, scope: .all)
        viewModel.showSource(kids)

        try await library.repository.delete(kids)
        viewModel.load()

        #expect(viewModel.sourceFilter == nil)
        #expect(viewModel.items.count == 4)
    }

    @Test("Adding a source while one is chosen goes back to all sources, so the new one shows")
    func newSourceShowsAll() async throws {
        let library = try TestLibrary()
        let tv = try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let viewModel = LibraryViewModel(repository: library.repository, scope: .all)
        viewModel.load()
        viewModel.showSource(tv)

        try await library.repository.addFilePlaylist(name: "Kids", text: secondPlaylist)
        viewModel.load()

        #expect(viewModel.sourceFilter == nil)
        #expect(viewModel.items.count == 6)
    }

    @Test("A media server's groups count items; a playlist's count channels")
    func serverGroupsCountItems() {
        func section(_ artwork: ArtworkStyle) -> LibrarySection {
            let item = MediaItem(
                id: UUID(),
                title: "A",
                group: "Movies",
                artworkURL: nil,
                streamURL: URL(fileURLWithPath: "/dev/null/a.mp4"),
                isLocalFile: false,
                isFavorite: false,
                artwork: artwork
            )
            return LibrarySection(title: "Movies", items: [item])
        }
        #expect(section(.poster).isFromServer)
        #expect(section(.still).isFromServer)
        #expect(!section(.logo).isFromServer)
    }

    // MARK: Group chips

    @Test("Chips are each group in playlist order, ungrouped as Other")
    func groupTitles() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let items = try library.repository.items()

        #expect(items.groupTitles == ["News", "Sports", String(appLocalized: "Other")])
        #expect(items.inGroup("News").map(\.title) == ["News One", "News Two"])
    }

    // MARK: A source's screen

    @Test("A source's screen opens on its first group, and each chip shows one group")
    func sourceDetailChips() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let viewModel = SourcesViewModel(repository: library.repository)
        viewModel.load()
        let detail = try viewModel.detail(for: #require(viewModel.sources.first))

        detail.load()
        #expect(detail.showsGroups)
        #expect(detail.groups == ["News", "Sports", String(appLocalized: "Other")])
        #expect(detail.group == "News")
        #expect(detail.visible.map(\.title) == ["News One", "News Two"])

        detail.group = "Sports"
        #expect(detail.visible.map(\.title) == ["Football Live"])
    }

    @Test("One group needs no chips")
    func sourceDetailSingleGroup() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "Kids", text: secondPlaylist)
        let viewModel = SourcesViewModel(repository: library.repository)
        viewModel.load()
        let detail = try viewModel.detail(for: #require(viewModel.sources.first))

        detail.load()

        #expect(!detail.showsGroups)
        #expect(detail.visible.count == 2)
    }

    @Test("A pasted or imported source can't be refreshed and has no link to copy")
    func fileSourceActions() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let viewModel = SourcesViewModel(repository: library.repository)
        viewModel.load()
        let detail = try viewModel.detail(for: #require(viewModel.sources.first))

        #expect(!detail.canRefresh)
        #expect(!detail.canCopyLink)
    }

    @Test("A link source refreshes, copies its link, renames and deletes from its screen")
    func remoteSourceActions() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        let sources = SourcesViewModel(repository: library.repository)
        sources.load()
        let detail = try sources.detail(for: #require(sources.sources.first))
        detail.load()

        #expect(detail.canRefresh)
        #expect(detail.canCopyLink)
        #expect(detail.link() == Fixtures.playlistURL.absoluteString)

        #expect(await detail.refresh())
        #expect(!detail.isRefreshing)
        #expect(library.fetcher.requested.count == 2)
        #expect(detail.items.count == 4)

        #expect(detail.rename(to: "  Living Room "))
        #expect(detail.name == "Living Room")
        #expect(!detail.rename(to: "   "))
        #expect(detail.name == "Living Room")

        #expect(await detail.delete())
        #expect(try library.repository.playlists().allSatisfy { $0.id != id })
    }

    @Test("A failed refresh on a source's screen reports why and keeps its channels")
    func remoteRefreshFailure() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        library.fetcher.stub(Fixtures.playlistURL, failing: .httpStatus(500))
        let sources = SourcesViewModel(repository: library.repository)
        sources.load()
        let detail = try sources.detail(for: #require(sources.sources.first))
        detail.load()

        #expect(await !detail.refresh())

        #expect(detail.errorMessage != nil)
        #expect(!detail.isRefreshing)
        #expect(detail.items.count == 4)
    }

    @Test("A link missing from the Keychain says so instead of copying nothing")
    func missingLink() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        try library.secureStore.removeAll()
        let sources = SourcesViewModel(repository: library.repository)
        sources.load()
        let detail = try sources.detail(for: #require(sources.sources.first))

        #expect(detail.link() == nil)
        #expect(detail.errorMessage != nil)
    }

    @Test("A heart tap on a source's screen updates the card at once")
    func sourceDetailFavorite() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let sources = SourcesViewModel(repository: library.repository)
        sources.load()
        let detail = try sources.detail(for: #require(sources.sources.first))
        detail.load()
        let item = try #require(detail.visible.first)

        #expect(detail.toggleFavorite(item) == true)

        #expect(detail.visible.first?.isFavorite == true)
        #expect(library.repository.isFavorite(item.id))
    }

    // MARK: Media servers

    @Test("A media server's row names the server, and its films keep their poster and year")
    func mediaServerPosters() async throws {
        let library = try TestLibrary()
        let film = try PlaylistEntry(
            name: "Dracula",
            group: "Movies",
            logoURL: URL(string: "http://nas.local/i/1.jpg"),
            streamURL: #require(URL(string: "http://nas.local/v/1.m3u8")),
            year: 1931,
            artwork: .poster
        )
        let episode = try PlaylistEntry(
            name: "S1 · E1 — Pilot",
            group: "Pioneer One",
            logoURL: nil,
            streamURL: #require(URL(string: "http://nas.local/v/2.m3u8")),
            artwork: .still
        )
        library.mediaServer.setEntries([film, episode])
        try await library.repository.addMediaServer(
            kind: .jellyfin,
            name: "Stable Demo",
            address: "https://demo.jellyfin.org",
            username: "demo",
            password: "pw"
        )
        let sources = SourcesViewModel(repository: library.repository)

        sources.load()

        #expect(sources.sources.first?.server == .jellyfin)
        let items = try library.repository.items()
        #expect(items.map(\.artwork) == [.poster, .still])
        #expect(items.map(\.year) == [1931, nil])
    }

    // MARK: The player's chips

    @Test("The player opens its chips on the playing item's group and plays from any group")
    func playerChips() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let items = try library.repository.items()
        let news = try #require(items.first { $0.title == "News Two" })
        let playback = PlaybackController()
        playback.play(news, queue: items.filter { $0.group == "News" })
        let viewModel = PlayerViewModel(playback: playback, repository: library.repository)

        viewModel.loadSource()

        #expect(viewModel.showsGroups)
        #expect(viewModel.group == "News")
        #expect(viewModel.gridItems.map(\.title) == ["News One", "News Two"])

        viewModel.group = "Sports"
        let football = try #require(viewModel.gridItems.first)
        viewModel.select(football)
        #expect(playback.current?.id == football.id)
        #expect(playback.queue.map(\.title) == ["Football Live"])
        playback.stop()
    }

    @Test("Without a readable source the player's grid is the queue, with no chips")
    func playerWithoutSource() throws {
        let library = try TestLibrary()
        let playback = PlaybackController()
        let item = MediaItem(
            id: UUID(),
            title: "Clip",
            group: "",
            artworkURL: nil,
            streamURL: URL(fileURLWithPath: "/dev/null/clip.mp4"),
            isLocalFile: true,
            isFavorite: false
        )
        playback.play(item, queue: [item])
        let viewModel = PlayerViewModel(playback: playback, repository: library.repository)

        viewModel.loadSource()

        #expect(!viewModel.showsGroups)
        #expect(viewModel.gridItems == [item])
        playback.stop()
    }
}
