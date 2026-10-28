import Foundation
import Testing
@testable import PlayCarTV

/// Which screen shows the video, the iPhone or the car's, and moving it between them (DECISIONS 155, 165).
@Suite("Playback origin")
@MainActor
struct PlaybackOriginTests {
    private func items(_ count: Int) -> [MediaItem] {
        (0..<count).map { index in
            MediaItem(
                id: UUID(),
                title: "Item \(index)",
                group: "G",
                artworkURL: nil,
                streamURL: URL(fileURLWithPath: "/dev/null/\(index).mp4"),
                isLocalFile: true,
                isFavorite: false
            )
        }
    }

    @Test("A pick on the car stays the car's through next and previous; the iPhone's next pick takes it back")
    func origin() {
        let controller = PlaybackController()
        let queue = items(3)
        #expect(controller.origin == .phone)
        controller.play(queue[0], queue: queue, from: .car)
        #expect(controller.origin == .car)
        controller.next()
        controller.previous()
        #expect(controller.origin == .car)
        controller.play(queue[2], queue: queue)
        #expect(controller.origin == .phone)
        controller.play(queue[1], queue: queue, from: .car)
        controller.stop()
        #expect(controller.origin == .phone)
    }

    @Test("Play on iPhone and Play on Car Display move what's playing without opening it again")
    func moveBetweenScreens() {
        let controller = PlaybackController()
        let queue = items(2)
        controller.move(to: .car)
        #expect(controller.origin == .phone, "Nothing playing, nothing to move")
        controller.play(queue[0], queue: queue, from: .car)
        controller.seek(to: 0)
        controller.move(to: .phone)
        #expect(controller.origin == .phone)
        #expect(controller.current?.id == queue[0].id)
        #expect(controller.queue.map(\.id) == queue.map(\.id))
        controller.move(to: .car)
        #expect(controller.origin == .car)
        #expect(controller.current?.id == queue[0].id)
        controller.stop()
    }
}
