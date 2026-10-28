import Foundation
import Testing
@testable import PlayCarTV

/// The iPhone's player while the video is on the car: Play on iPhone, Play on Car Display, and picks (DECISIONS 165).
@Suite("Player on the car")
@MainActor
struct PlayerOnCarTests {
    @Test("Play on Car Display shows only with PlayCarTV on the car's screen and the video on the iPhone")
    func playOnCar() throws {
        let library = try TestLibrary()
        let playback = PlaybackController()
        let connection = CarConnection()
        let item = MediaItem(
            id: UUID(),
            title: "Clip",
            group: "",
            artworkURL: nil,
            streamURL: URL(fileURLWithPath: "/dev/null/clip.mp4"),
            isLocalFile: true,
            isFavorite: false
        )
        let viewModel = PlayerViewModel(playback: playback, repository: library.repository, carConnection: connection)
        playback.play(item, queue: [item])
        #expect(!viewModel.canPlayOnCar, "No car")

        connection.isCarPlayConnected = true
        #expect(viewModel.canPlayOnCar)
        viewModel.playOnCar()
        #expect(viewModel.isOnCar)
        #expect(!viewModel.canPlayOnCar, "Already on the car")

        viewModel.playOnPhone()
        #expect(!viewModel.isOnCar)
        #expect(viewModel.canPlayOnCar)
        playback.stop()
    }

    @Test("A pick on the iPhone while the video is on the car plays on the car")
    func pickWhileOnCar() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let items = try library.repository.items()
        let news = try #require(items.first { $0.title == "News One" })
        let other = try #require(items.first { $0.title == "News Two" })
        let playback = PlaybackController()
        playback.play(news, queue: [news, other], from: .car)
        let viewModel = PlayerViewModel(playback: playback, repository: library.repository)

        viewModel.select(other)

        #expect(playback.current?.id == other.id)
        #expect(playback.origin == .car)
        playback.stop()
    }
}
