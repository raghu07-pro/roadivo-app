import Foundation
import Testing
@testable import Roadivo

/// How a video starts: a file on the iPhone at once, a stream once it has enough to play smoothly.
@Suite("Playback start")
@MainActor
struct PlaybackStartTests {
    private func item(local: Bool) -> MediaItem {
        MediaItem(
            id: UUID(),
            title: local ? "Clip" : "Channel",
            group: "G",
            artworkURL: nil,
            streamURL: local ? URL(fileURLWithPath: "/dev/null/clip.mp4") : URL(string: "https://e.com/live.m3u8")!,
            isLocalFile: local,
            isFavorite: false
        )
    }

    @Test("A file on the iPhone starts without waiting to judge buffering; a stream still waits for enough to play")
    func waitsOnlyForStreams() {
        let controller = PlaybackController()
        let file = item(local: true)
        controller.play(file, queue: [file], from: .car)
        #expect(!controller.player.automaticallyWaitsToMinimizeStalling)

        let stream = item(local: false)
        controller.play(stream, queue: [stream])
        #expect(controller.player.automaticallyWaitsToMinimizeStalling)
        controller.stop()
    }
}
