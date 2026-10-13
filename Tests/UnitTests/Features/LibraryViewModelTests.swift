import Foundation
import Testing
@testable import Roadivo

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
}
