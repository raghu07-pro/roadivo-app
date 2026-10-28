import Foundation
import Testing
@testable import PlayCarTV

@Suite("Library view model")
@MainActor
struct LibraryViewModelTests {
    private func loaded(_ scope: LibraryScope = .all) async throws -> (LibraryViewModel, TestLibrary) {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let viewModel = LibraryViewModel(repository: library.repository, scope: scope)
        viewModel.load()
        return (viewModel, library)
    }

    @Test("An empty library reports .empty")
    func empty() throws {
        let viewModel = try LibraryViewModel(repository: TestLibrary().repository, scope: .all)
        viewModel.load()
        #expect(viewModel.phase == .empty)
    }

    @Test("Home leaves out imported videos; they stay on the On this iPhone shelf")
    func homeSkipsImportedVideos() async throws {
        let (viewModel, library) = try await loaded()
        let video = FileManager.default.temporaryDirectory.appending(path: "Beach Day \(UUID().uuidString).mp4")
        try Data("not really a video".utf8).write(to: video)
        defer { try? FileManager.default.removeItem(at: video) }
        #expect(try await library.repository.importVideos([video]) == 1)
        let local = try #require(try library.repository.localVideos().first)
        library.repository.markPlayed(local.id)

        viewModel.load()
        #expect(!viewModel.items.contains { $0.isLocalFile })
        #expect(!viewModel.recent.contains { $0.isLocalFile })
        #expect(!viewModel.sections.map(\.title).contains("On this iPhone"))
        #expect(try library.repository.localVideos().count == 1)
    }

    @Test("Continue Watching keeps channels after more than 12 videos were played since")
    func recentSkipsVideosBeforeTheLimit() async throws {
        let (viewModel, library) = try await loaded()
        let news = try #require(viewModel.items.first)
        library.repository.markPlayed(news.id, at: Date(timeIntervalSince1970: 1))
        let folder = FileManager.default.temporaryDirectory.appending(path: "recent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let files = try (0..<13).map { index in
            let file = folder.appending(path: "Clip \(index).mp4")
            try Data("x".utf8).write(to: file)
            return file
        }
        try await library.repository.importVideos(files)
        let videos = try library.repository.localVideos()
        defer {
            for video in videos {
                try? library.repository.deleteVideo(video.id) // Also removes the copied file.
            }
        }
        #expect(videos.count == 13)
        for (offset, video) in videos.enumerated() {
            library.repository.markPlayed(video.id, at: Date(timeIntervalSince1970: Double(10 + offset)))
        }

        viewModel.load()
        #expect(viewModel.recent.map(\.id) == [news.id])
    }

    @Test("Groups items into sections in playlist order, ungrouped as Other")
    func sections() async throws {
        let (viewModel, _) = try await loaded()
        #expect(viewModel.phase == .loaded)
        #expect(viewModel.sections.map(\.title) == ["News", "Sports", "Other"])
        #expect(viewModel.sections.first?.items.count == 2)
    }

    @Test("Search matches titles and groups, case-insensitively")
    func search() async throws {
        let (viewModel, _) = try await loaded()
        viewModel.query = "FOOT"
        #expect(viewModel.filtered.map(\.title) == ["Football Live"])
        viewModel.query = "news"
        #expect(viewModel.filtered.count == 2)
        viewModel.query = "zzz"
        #expect(viewModel.sections.isEmpty)
    }

    @Test("The play queue is the item's own group")
    func queue() async throws {
        let (viewModel, _) = try await loaded()
        let news = try #require(viewModel.items.first)
        #expect(viewModel.queue(for: news).map(\.title) == ["News One", "News Two"])
    }

    @Test("Favourites scope shows only favourites and updates on toggle")
    func favorites() async throws {
        let (all, library) = try await loaded()
        let target = try #require(all.items.last)
        #expect(all.toggleFavorite(target) == true)

        let favorites = LibraryViewModel(repository: library.repository, scope: .favorites)
        favorites.load()
        #expect(favorites.items.map(\.title) == [target.title])
        #expect(favorites.toggleFavorite(target) == false)
        #expect(favorites.phase == .empty)
    }

    @Test("See All shows a favourite added on that screen")
    func seeAllShowsFavoriteChange() async throws {
        let (viewModel, _) = try await loaded()
        let football = try #require(viewModel.items(inGroup: "Sports").first)
        #expect(!football.isFavorite)

        #expect(viewModel.toggleFavorite(football) == true)

        #expect(viewModel.items(inGroup: "Sports").first?.isFavorite == true)
        #expect(viewModel.toggleFavorite(football) == false)
        #expect(viewModel.items(inGroup: "Sports").first?.isFavorite == false)
    }

    @Test("A heart tap updates Home and Continue Watching in place")
    func favoriteUpdatesInPlace() async throws {
        let (viewModel, library) = try await loaded()
        let news = try #require(viewModel.items.first)
        library.repository.markPlayed(news.id)
        viewModel.load()

        #expect(viewModel.toggleFavorite(news) == true)

        #expect(viewModel.items.first?.isFavorite == true)
        #expect(viewModel.recent.first?.isFavorite == true)
        #expect(try library.repository.favorites().map(\.id) == [news.id])
    }

    @Test("A group that no longer exists has no items")
    func missingGroup() async throws {
        let (viewModel, _) = try await loaded()
        #expect(viewModel.items(inGroup: "Nope").isEmpty)
    }

    @Test("Continue Watching lists played items, newest first")
    func recent() async throws {
        let (viewModel, library) = try await loaded()
        library.repository.markPlayed(viewModel.items[3].id, at: Date(timeIntervalSince1970: 1))
        library.repository.markPlayed(viewModel.items[0].id, at: Date(timeIntervalSince1970: 2))
        viewModel.load()
        #expect(viewModel.recent.map(\.title) == ["News One", "Untitled Movie"])
    }

    @Test("Continue Watching shows a film's progress and drops it once watched to the end")
    func recentShowsProgress() async throws {
        let (viewModel, library) = try await loaded()
        let movie = try #require(viewModel.items.first { $0.title == "Untitled Movie" })
        library.repository.markPlayed(movie.id)
        library.repository.saveProgress(PlaybackProgress(position: 1500, duration: 3600), for: movie.id)
        viewModel.load()
        #expect(viewModel.recent.first?.progress?.position == 1500)
        #expect(viewModel.items.first { $0.id == movie.id }?.progress?.position == 1500)

        library.repository.saveProgress(PlaybackProgress(position: 3500, duration: 3600), for: movie.id)
        viewModel.load()
        #expect(viewModel.recent.isEmpty)
    }

    @Test("Removing an item takes it out of Continue Watching at once and for good")
    func removeFromHistory() async throws {
        let (viewModel, library) = try await loaded()
        library.repository.markPlayed(viewModel.items[0].id, at: Date(timeIntervalSince1970: 1))
        library.repository.markPlayed(viewModel.items[2].id, at: Date(timeIntervalSince1970: 2))
        viewModel.load()
        let football = try #require(viewModel.recent.first)

        #expect(viewModel.removeFromHistory(football))
        #expect(viewModel.recent.map(\.title) == ["News One"])
        viewModel.load()
        #expect(viewModel.recent.map(\.title) == ["News One"])
    }
}
