import AVFoundation
import MediaPlayer
import Observation
import OSLog

/// The app's single player. Lives above every screen so playback continues
/// while the user browses (mini player), in Car Mode, in Picture in Picture
/// and in the background. Lock screen and steering-wheel buttons reach it
/// through the remote command center.
@Observable
@MainActor
final class PlaybackController {
    enum Status: Equatable {
        case idle
        case loading
        case playing
        case paused
        case failed(String)
    }

    let player = AVPlayer()
    private(set) var current: MediaItem?
    private(set) var queue: [MediaItem] = []
    private(set) var status: Status = .idle
    /// Seconds; `nil` for a live stream with no fixed length.
    private(set) var duration: Double?
    private(set) var elapsed: Double = 0

    var isActive: Bool {
        current != nil
    }

    var isPlaying: Bool {
        status == .playing || status == .loading
    }

    var isLive: Bool {
        current != nil && duration == nil
    }

    var hasNext: Bool {
        index.map { $0 + 1 < queue.count } ?? false
    }

    var hasPrevious: Bool {
        index.map { $0 > 0 } ?? false
    }

    /// Called whenever a new item starts, so the library can record history.
    var onItemStarted: ((MediaItem) -> Void)?

    @ObservationIgnored private var playerObservation: NSKeyValueObservation?
    @ObservationIgnored private var itemObservation: NSKeyValueObservation?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var commandsInstalled = false
    @ObservationIgnored private let logger = Logger(subsystem: "com.roadivo", category: "Playback")

    private var index: Int? {
        guard let current else { return nil }
        return queue.firstIndex { $0.id == current.id }
    }

    init() {
        player.allowsExternalPlayback = true
        observePlayer()
    }

    // MARK: Intents

    /// Plays `item`; `queue` is what next/previous step through (usually the item's group).
    func play(_ item: MediaItem, queue: [MediaItem]) {
        activateAudioSession()
        installRemoteCommands()
        self.queue = queue.contains(item) ? queue : [item]
        current = item
        duration = nil
        elapsed = 0
        status = .loading
        let playerItem = AVPlayerItem(url: item.streamURL)
        playerItem.preferredForwardBufferDuration = 8
        observeItem(playerItem)
        player.replaceCurrentItem(with: playerItem)
        player.play()
        updateNowPlaying()
        onItemStarted?(item)
    }

    func togglePlayPause() {
        guard current != nil else { return }
        if player.timeControlStatus == .paused {
            if case .failed = status, let current {
                play(current, queue: queue)
            } else {
                player.play()
            }
        } else {
            player.pause()
        }
    }

    func next() {
        guard let index, index + 1 < queue.count else { return }
        play(queue[index + 1], queue: queue)
    }

    func previous() {
        guard let index, index > 0 else { return }
        play(queue[index - 1], queue: queue)
    }

    func skip(by seconds: Double) {
        guard duration != nil else { return }
        let target = max(0, player.currentTime().seconds + seconds)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    func updateFavorite(_ isFavorite: Bool, for id: UUID) {
        if current?.id == id {
            current?.isFavorite = isFavorite
        }
        if let position = queue.firstIndex(where: { $0.id == id }) {
            queue[position].isFavorite = isFavorite
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        current = nil
        queue = []
        status = .idle
        duration = nil
        elapsed = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: Observation

    private func observePlayer() {
        // KVO can fire off the main thread, so the handlers are @Sendable and hop back.
        playerObservation = player.observe(\.timeControlStatus, options: [.new]) { @Sendable [weak self] player, _ in
            let value = player.timeControlStatus
            Task { @MainActor [weak self] in self?.apply(value) }
        }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                self?.elapsed = time.seconds.isFinite ? time.seconds : 0
            }
        }
    }

    private func observeItem(_ item: AVPlayerItem) {
        itemObservation = item.observe(\.status, options: [.new]) { @Sendable [weak self] item, _ in
            let failed = item.status == .failed
            let message = item.error?.localizedDescription
            let seconds = item.duration.seconds
            let itemID = ObjectIdentifier(item)
            Task { @MainActor [weak self] in
                guard let self, player.currentItem.map(ObjectIdentifier.init) == itemID else { return }
                if failed {
                    logger.error("Item failed: \(message ?? "unknown", privacy: .public)")
                    status = .failed(String(appLocalized: "This stream can't be played right now."))
                } else if seconds.isFinite, seconds > 0 {
                    duration = seconds
                    updateNowPlaying()
                }
            }
        }
    }

    private func apply(_ value: AVPlayer.TimeControlStatus) {
        if case .failed = status {
            return
        }
        guard current != nil else { return }
        switch value {
        case .playing: status = .playing
        case .waitingToPlayAtSpecifiedRate: status = .loading
        case .paused: status = .paused
        @unknown default: break
        }
        updateNowPlaying()
    }

    // MARK: System integration

    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("Audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func installRemoteCommands() {
        guard !commandsInstalled else { return }
        commandsInstalled = true
        let center = MPRemoteCommandCenter.shared()
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.togglePlayPause() }
            return .success
        }
        center.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.player.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.player.pause() }
            return .success
        }
        // Steering-wheel "next track" switches channel.
        center.nextTrackCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.previous() }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.title,
            MPMediaItemPropertyArtist: current.groupTitle,
            MPNowPlayingInfoPropertyIsLiveStream: duration == nil,
            MPNowPlayingInfoPropertyPlaybackRate: status == .playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed
        ]
        if let duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
