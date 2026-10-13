import Foundation
import Testing
@testable import Roadivo

@Suite("Playback controller")
@MainActor
struct PlaybackControllerTests {
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

    @Test("Next and previous step through the queue and stop at its ends")
    func queueNavigation() {
        let controller = PlaybackController()
        let queue = items(3)
        var started: [String] = []
        controller.onItemStarted = { started.append($0.title) }

        controller.play(queue[0], queue: queue)
        #expect(controller.isActive)
        #expect(!controller.hasPrevious)
        #expect(controller.hasNext)

        controller.next()
        controller.next()
        #expect(controller.current?.title == "Item 2")
        #expect(!controller.hasNext)
        controller.next()
        #expect(controller.current?.title == "Item 2")

        controller.previous()
        #expect(controller.current?.title == "Item 1")
        #expect(started == ["Item 0", "Item 1", "Item 2", "Item 1"])
    }

    @Test("An item outside the queue plays on its own")
    func outsideQueue() {
        let controller = PlaybackController()
        let other = items(1)[0]
        controller.play(other, queue: items(2))
        #expect(controller.queue == [other])
    }

    @Test("Favourite changes reach the current item and the queue")
    func favoriteSync() {
        let controller = PlaybackController()
        let queue = items(2)
        controller.play(queue[0], queue: queue)
        controller.updateFavorite(true, for: queue[0].id)
        #expect(controller.current?.isFavorite == true)
        #expect(controller.queue.first?.isFavorite == true)
    }

    @Test("Stop clears everything")
    func stop() {
        let controller = PlaybackController()
        let queue = items(2)
        controller.play(queue[0], queue: queue)
        controller.stop()
        #expect(!controller.isActive)
        #expect(controller.queue.isEmpty)
        #expect(controller.status == .idle)
    }
}
