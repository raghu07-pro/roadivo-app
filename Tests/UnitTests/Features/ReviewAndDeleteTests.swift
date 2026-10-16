import Foundation
import Testing
@testable import Roadivo

@Suite("Review prompt and video delete")
@MainActor
struct ReviewAndDeleteTests {
    @Test("Asks after the 1st, 10th, 25th video, then every 25th")
    func milestones() {
        let asked = (1...130).filter(ReviewMilestones.shouldAsk(afterOpening:))
        #expect(asked == [1, 10, 25, 50, 75, 100, 125])
    }

    @Test("Opening videos counts toward the prompt and requests it at milestones")
    func countsOpens() throws {
        let defaults = try #require(UserDefaults(suiteName: "roadivo.tests.\(UUID().uuidString)"))
        let environment = try AppEnvironment(
            apiClient: nil,
            store: SwiftDataStore(inMemory: true),
            secureStore: InMemorySecureStore(),
            fetcher: StubFetcher(),
            mediaServers: StubMediaServer(),
            storeClient: FakeStoreClient(),
            preferences: Preferences(defaults: defaults),
            displayProfiles: DisplayProfileStore(defaults: defaults)
        )
        let item = MediaItem(
            id: UUID(),
            title: "Clip",
            group: "",
            artworkURL: nil,
            streamURL: URL(fileURLWithPath: "/dev/null/clip.mp4"),
            isLocalFile: true,
            isFavorite: false
        )
        environment.playback.play(item, queue: [item])
        #expect(environment.preferences.videosOpened == 1)
        #expect(environment.router.reviewRequests == 1)
        for _ in 2...9 {
            environment.playback.play(item, queue: [item])
        }
        #expect(environment.router.reviewRequests == 1)
        environment.playback.play(item, queue: [item])
        #expect(environment.router.reviewRequests == 2)
        environment.playback.stop()
    }

    @Test("Deleting a video removes the row and its copied file")
    func deleteVideo() async throws {
        let library = try TestLibrary()
        let source = FileManager.default.temporaryDirectory.appending(path: "Trip \(UUID().uuidString).mp4")
        try Data("x".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        try await library.repository.importVideos([source])
        let video = try #require(try library.repository.localVideos().first)
        let copy = video.streamURL.path(percentEncoded: false)
        #expect(FileManager.default.fileExists(atPath: copy))

        let viewModel = LocalVideosViewModel(repository: library.repository)
        #expect(viewModel.delete(video))
        #expect(viewModel.items.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: copy))
    }

    @Test("A failed delete is reported as a delete problem, not an import")
    func failedDeleteIsADeleteProblem() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let channel = try #require(try library.repository.items().first)
        let viewModel = LocalVideosViewModel(repository: library.repository)

        #expect(!viewModel.delete(channel))
        #expect(viewModel.problem?.kind == .delete)
    }

    @Test("Photos picks that failed are reported after the rest are imported")
    func partialPhotosImportReportsAfterwards() async throws {
        let library = try TestLibrary()
        let source = FileManager.default.temporaryDirectory.appending(path: "Pier \(UUID().uuidString).mp4")
        try Data("x".utf8).write(to: source)
        let viewModel = LocalVideosViewModel(repository: library.repository)

        let added = await viewModel.importFiles([source], skipped: 1, removingSourcesAfterwards: true)
        defer {
            for video in viewModel.items {
                _ = viewModel.delete(video) // Removes the copied file.
            }
        }

        #expect(added)
        #expect(viewModel.items.count == 1)
        #expect(!viewModel.isImporting)
        #expect(viewModel.problem?.kind == .importing)
        #expect(viewModel.problem?.message == String(appLocalized: "\(1) of \(2) videos were imported."))
        #expect(!FileManager.default.fileExists(atPath: source.path(percentEncoded: false)))
    }

    @Test("When every Photos pick failed, nothing imports and the problem is reported")
    func allPhotosPicksFailed() async throws {
        let viewModel = try LocalVideosViewModel(repository: TestLibrary().repository)
        let added = await viewModel.importFiles([], skipped: 2)
        #expect(!added)
        #expect(viewModel.problem?.kind == .importing)
    }

    @Test("Nothing picked: no import and no alert")
    func nothingPickedHasNoProblem() async throws {
        let viewModel = try LocalVideosViewModel(repository: TestLibrary().repository)
        let added = await viewModel.importFiles([])
        #expect(!added)
        #expect(viewModel.problem == nil)
    }

    @Test("Streams can't be deleted one by one")
    func streamsNotDeletable() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let channel = try #require(try library.repository.items().first)
        #expect(throws: LibraryError.notFound) { try library.repository.deleteVideo(channel.id) }
        #expect(channel.deleteAction { _ in } == nil)
    }
}
