import AVFoundation
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

    @Test("Seeking does nothing on a stream with no fixed length")
    func seekingWithoutDuration() {
        let controller = PlaybackController()
        let queue = items(1)
        controller.play(queue[0], queue: queue)
        #expect(controller.duration == nil)
        controller.seek(to: 30)
        #expect(controller.elapsed == 0)
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

    @Test("The player's clock reads m:ss, or h:mm:ss past an hour")
    func clock() {
        #expect(PlayerControls.clock(7) == "0:07")
        #expect(PlayerControls.clock(760) == "12:40")
        #expect(PlayerControls.clock(3725) == "1:02:05")
        #expect(PlayerControls.clock(.nan) == "0:00")
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

    @Test("An item opens at its saved place; Play from Beginning skips it")
    func opensAtSavedPlace() {
        let controller = PlaybackController()
        let store = FakeProgressStore()
        controller.progressStore = store
        let queue = items(2)
        store.places[queue[0].id] = 1500

        controller.play(queue[0], queue: queue)
        #expect(controller.elapsed == 1500)
        #expect(controller.isOpeningAtSavedPlace)
        #expect(controller.status == .loading)

        controller.play(queue[0], queue: queue, startingOver: true)
        #expect(controller.elapsed == 0)
        #expect(!controller.isOpeningAtSavedPlace)
    }

    @Test("An item that never loaded keeps the place it had")
    func unloadedKeepsPlace() {
        let controller = PlaybackController()
        let store = FakeProgressStore()
        controller.progressStore = store
        let queue = items(2)
        store.places[queue[0].id] = 1500

        controller.play(queue[0], queue: queue)
        controller.next()
        controller.stop()

        #expect(store.saved.isEmpty)
    }

    @Test("Pausing while it opens at a saved place stays paused, and Play carries on opening")
    func pauseWhileOpening() {
        let controller = PlaybackController()
        let store = FakeProgressStore()
        controller.progressStore = store
        let queue = items(1)
        store.places[queue[0].id] = 1500
        controller.play(queue[0], queue: queue)

        controller.togglePlayPause()
        #expect(controller.status == .paused)
        #expect(!controller.isOpeningAtSavedPlace)

        controller.togglePlayPause()
        #expect(controller.status == .loading)
        #expect(controller.isOpeningAtSavedPlace)
    }

    @Test("A video that fails while opening at its saved place shows the error, and Play retries from there")
    func failWhileOpening() async {
        let missing = FileManager.default.temporaryDirectory.appending(path: "missing-\(UUID().uuidString).mp4")
        let item = MediaItem(
            id: UUID(),
            title: "Gone",
            group: "G",
            artworkURL: nil,
            streamURL: missing,
            isLocalFile: true,
            isFavorite: false
        )
        let controller = PlaybackController()
        let store = FakeProgressStore()
        controller.progressStore = store
        store.places[item.id] = 1500
        controller.play(item, queue: [item])

        await waitUntil {
            if case .failed = controller.status {
                true
            } else {
                false
            }
        }
        guard case .failed = controller.status else {
            Issue.record("The missing file never failed")
            return
        }
        #expect(!controller.isOpeningAtSavedPlace)

        controller.togglePlayPause()
        #expect(controller.status == .loading)
        #expect(controller.isOpeningAtSavedPlace)
        #expect(controller.elapsed == 1500)
    }

    @Test("With Play Next Automatically off, the end of a video stays on it; on, the next one starts")
    func playsNextSetting() async throws {
        let movie = try await makeTestMovie(seconds: 1)
        defer { try? FileManager.default.removeItem(at: movie) }
        let queue = (0..<2).map { index in
            MediaItem(
                id: UUID(),
                title: "Clip \(index)",
                group: "G",
                artworkURL: nil,
                streamURL: movie,
                isLocalFile: true,
                isFavorite: false
            )
        }
        let controller = PlaybackController()
        controller.upNextDelay = 1
        controller.playsNextAutomatically = false

        controller.play(queue[0], queue: queue)
        await waitUntil { controller.status == .paused }
        #expect(controller.current?.id == queue[0].id)
        #expect(controller.upNext == nil)

        controller.playsNextAutomatically = true
        controller.play(queue[0], queue: queue)
        await waitUntil { controller.current?.id == queue[1].id }
        #expect(controller.current?.id == queue[1].id)
    }

    /// Two one-second clips and a controller that counts down a second, on screen or not.
    private struct Clips {
        let controller: PlaybackController
        let queue: [MediaItem]
        let movie: URL
    }

    private func endingClips(inForeground: Bool) async throws -> Clips {
        let movie = try await makeTestMovie(seconds: 1)
        let queue = (0..<2).map { index in
            MediaItem(
                id: UUID(),
                title: "Clip \(index)",
                group: "G",
                artworkURL: nil,
                streamURL: movie,
                isLocalFile: true,
                isFavorite: false
            )
        }
        let controller = PlaybackController()
        controller.upNextDelay = 1
        controller.isInForeground = { inForeground }
        return Clips(controller: controller, queue: queue, movie: movie)
    }

    @Test("A video that ends counts down to the next, then plays it")
    func upNextCountsDown() async throws {
        let clips = try await endingClips(inForeground: true)
        let (controller, queue, movie) = (clips.controller, clips.queue, clips.movie)
        defer { try? FileManager.default.removeItem(at: movie) }

        controller.play(queue[0], queue: queue)
        await waitUntil { controller.upNext != nil }
        #expect(controller.upNext?.item.id == queue[1].id)
        #expect(controller.current?.id == queue[0].id)

        await waitUntil { controller.current?.id == queue[1].id }
        #expect(controller.current?.id == queue[1].id)
        #expect(controller.upNext == nil)
    }

    @Test("Cancel stays on the video that ended; Play Now skips the wait")
    func upNextCancelAndPlayNow() async throws {
        let clips = try await endingClips(inForeground: true)
        let (controller, queue, movie) = (clips.controller, clips.queue, clips.movie)
        defer { try? FileManager.default.removeItem(at: movie) }

        controller.play(queue[0], queue: queue)
        await waitUntil { controller.upNext != nil }
        controller.cancelUpNext()
        await waitUntil(seconds: 2) { controller.current?.id == queue[1].id } // Time for it to (not) finish.
        #expect(controller.current?.id == queue[0].id)
        #expect(controller.upNext == nil)

        controller.play(queue[0], queue: queue)
        await waitUntil { controller.upNext != nil }
        controller.playUpNextNow()
        #expect(controller.current?.id == queue[1].id)
    }

    @Test("In the background the next video plays at once, and starting another cancels the countdown")
    func upNextInTheBackground() async throws {
        let clips = try await endingClips(inForeground: false)
        let (background, queue) = (clips.controller, clips.queue)
        defer { try? FileManager.default.removeItem(at: clips.movie) }
        background.play(queue[0], queue: queue)
        await waitUntil { background.current?.id == queue[1].id }
        #expect(background.current?.id == queue[1].id)

        let screenClips = try await endingClips(inForeground: true)
        defer { try? FileManager.default.removeItem(at: screenClips.movie) }
        let onScreen = screenClips.controller
        onScreen.play(queue[0], queue: queue)
        await waitUntil { onScreen.upNext != nil }
        onScreen.play(queue[0], queue: queue)
        #expect(onScreen.upNext == nil)
        onScreen.stop()
        background.stop()
    }

    @Test("A real video starts at its saved place and keeps the place it reached when stopped")
    func resumesRealVideo() async throws {
        let movie = try await makeTestMovie(seconds: 40, fps: 2)
        defer { try? FileManager.default.removeItem(at: movie) }
        let item = MediaItem(
            id: UUID(),
            title: "Movie",
            group: "G",
            artworkURL: nil,
            streamURL: movie,
            isLocalFile: true,
            isFavorite: false
        )
        let controller = PlaybackController()
        let store = FakeProgressStore()
        controller.progressStore = store
        store.places[item.id] = 25

        controller.play(item, queue: [item])
        await waitUntil { controller.status == .playing }

        #expect(controller.status == .playing)
        #expect(controller.player.currentTime().seconds >= 23) // The seek may land up to 2 s early.
        controller.stop()
        let kept = try #require(store.saved.last)
        #expect(kept.id == item.id)
        #expect(kept.progress.position >= 23)
        #expect(abs(kept.progress.duration - 40) < 0.5)
    }

    /// Polls for up to `seconds` (10 by default); a real video takes a moment to load and seek.
    private func waitUntil(seconds: Int = 10, _ condition: () -> Bool) async {
        for _ in 0..<(seconds * 100) where !condition() {
            try? await Task.sleep(for: .milliseconds(10)) // Polling; a cancelled sleep just polls sooner.
        }
    }
}

// MARK: - What else stops the countdown

extension PlaybackControllerTests {
    @Test("Voice search, a call, a deleted next video or a screen set not to play on all cancel the countdown")
    func upNextCancelledByTheRest() async throws {
        let clips = try await endingClips(inForeground: true)
        let (controller, queue) = (clips.controller, clips.queue)
        defer { try? FileManager.default.removeItem(at: clips.movie) }
        var noAutoplay = DisplayProfile(id: UUID(), name: "Car", receiver: nil)
        noAutoplay.playsNextAutomatically = false
        let interruption = [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        let stoppers: [(String, () -> Void)] = [
            ("voice search", { #expect(!controller.pauseForMicrophone()) }),
            ("a call", {
                NotificationCenter.default.post(
                    name: AVAudioSession.interruptionNotification, object: nil, userInfo: interruption
                )
            }),
            ("a deleted next video", { controller.forget([queue[1].id]) }),
            ("a screen set not to play on", { controller.apply(noAutoplay) })
        ]
        for (name, stop) in stoppers {
            controller.playsNextAutomatically = true
            controller.play(queue[0], queue: queue)
            await waitUntil { controller.upNext != nil }
            stop()
            await waitUntil(seconds: 2) { controller.current?.id == queue[1].id } // Time for it to (not) play.
            #expect(controller.upNext == nil, "\(name)")
            #expect(controller.current?.id == queue[0].id, "\(name)")
        }
        controller.stop()
    }

    @Test("Leaving the app mid-countdown plays the card's video at once")
    func upNextLeavingTheApp() async throws {
        let clips = try await endingClips(inForeground: true)
        let (controller, queue) = (clips.controller, clips.queue)
        defer { try? FileManager.default.removeItem(at: clips.movie) }

        controller.play(queue[0], queue: queue)
        await waitUntil { controller.upNext != nil }
        controller.enteredBackground()
        #expect(controller.upNext == nil)
        #expect(controller.current?.id == queue[1].id)
        controller.stop()
    }
}

/// Answers with saved places and records what the player keeps.
@MainActor
private final class FakeProgressStore: PlaybackProgressStoring {
    var places: [UUID: Double] = [:]
    private(set) var saved: [(id: UUID, progress: PlaybackProgress)] = []

    func resumePosition(for id: UUID) -> Double? {
        places[id]
    }

    func saveProgress(_ progress: PlaybackProgress, for id: UUID) {
        saved.append((id, progress))
    }
}
