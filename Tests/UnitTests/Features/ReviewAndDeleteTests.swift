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
            preferences: Preferences(defaults: defaults)
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

    @Test("Streams can't be deleted one by one")
    func streamsNotDeletable() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let channel = try #require(try library.repository.items().first)
        #expect(throws: LibraryError.notFound) { try library.repository.deleteVideo(channel.id) }
        #expect(channel.deleteAction { _ in } == nil)
    }
}
