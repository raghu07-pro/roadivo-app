import Foundation
import Testing
@testable import Roadivo

@Suite("Sources")
@MainActor
struct SourcesViewModelTests {
    @Test("Lists, renames, refreshes and deletes sources")
    func lifecycle() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        let viewModel = SourcesViewModel(repository: library.repository)

        viewModel.load()
        let source = try #require(viewModel.sources.first)
        #expect(source.itemCount == 4)
        #expect(source.kind == .remote)
        #expect(source.host == "iptv.example.com")

        #expect(viewModel.rename(id, to: "Living Room"))
        #expect(viewModel.sources.first?.name == "Living Room")

        #expect(await viewModel.refresh(id))
        #expect(library.fetcher.requested.count == 2)

        #expect(await viewModel.delete(id))
        #expect(viewModel.sources.isEmpty)
    }

    @Test("A failed refresh reports an error")
    func refreshFailure() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        library.fetcher.stub(Fixtures.playlistURL, failing: .httpStatus(500))
        let viewModel = SourcesViewModel(repository: library.repository)

        #expect(await !viewModel.refresh(id))
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.refreshing.isEmpty)
    }

    @Test("A source restored to a new iPhone without its link asks to be added again")
    func refreshWithoutSecret() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        let id = try await library.repository.addRemotePlaylist(name: "TV", url: Fixtures.playlistURL)
        try library.secureStore.removeAll()
        let viewModel = SourcesViewModel(repository: library.repository)

        #expect(await !viewModel.refresh(id))
        #expect(viewModel.errorMessage == SourceSecretError.missing.localizedDescription)
    }

    @Test("Item counts are per source, and deleting one leaves the other")
    func countsAndDelete() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "Small", text: Fixtures.playlist)
        let big = try await library.repository.addFilePlaylist(name: "Big", text: bigPlaylist(1500))
        let viewModel = SourcesViewModel(repository: library.repository)

        viewModel.load()
        #expect(viewModel.sources.map(\.itemCount) == [4, 1500])

        #expect(await viewModel.delete(big))
        #expect(viewModel.sources.map(\.name) == ["Small"])
        #expect(try library.repository.items().count == 4)
    }
}
