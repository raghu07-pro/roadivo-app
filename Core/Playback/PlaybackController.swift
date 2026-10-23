import AVFoundation
import MediaPlayer
import Observation
import OSLog
import UIKit

/// The app's single player, above every screen, so playback continues in the mini player, Car Mode,
/// PiP and the background. Lock screen and steering-wheel buttons reach it via remote commands.
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
    private(set) var origin: PlaybackOrigin = .phone
    private(set) var queue: [MediaItem] = []
    private(set) var status: Status = .idle
    /// Seconds; `nil` for a live stream with no fixed length.
    private(set) var duration: Double?
    private(set) var elapsed: Double = 0
    /// The AirPlay screen the video is on (a car display, an adapter, a TV); nil on this iPhone.
    private(set) var externalScreen: String?
    /// The connected screen's profile, set through `apply(_:)`: how the picture meets the screen,
    /// whether the next video follows, and which subtitles play.
    var videoGravity: AVLayerVideoGravity = .resizeAspect
    @ObservationIgnored var playsNextAutomatically = true
    @ObservationIgnored var subtitles: SubtitleMode = .automatic
    @ObservationIgnored var subtitleTask: Task<Void, Never>?
    /// After a video ends, the next one counting down (`+UpNext`): its seconds (fewer in tests), and
    /// whether the app is on screen, as in the background the next video starts at once.
    var upNext: UpNext?
    @ObservationIgnored var upNextTask: Task<Void, Never>?
    @ObservationIgnored var upNextDelay = 5
    /// How long the player's controls stay up while playing; UI tests lengthen it so a tap never races the hide.
    @ObservationIgnored var controlsHideDelay: Duration = .seconds(3)
    @ObservationIgnored var isInForeground: @MainActor () -> Bool = { UIApplication.shared.applicationState == .active }

    var isActive: Bool {
        current != nil
    }

    var isPlaying: Bool {
        status == .playing || status == .loading
    }

    var isLive: Bool {
        current != nil && duration == nil
    }

    /// Waiting for the seek to a saved place, and set to play once it lands.
    var isOpeningAtSavedPlace: Bool {
        isOpening && !staysPaused
    }

    var hasNext: Bool {
        index.map { $0 + 1 < queue.count } ?? false
    }

    var hasPrevious: Bool {
        index.map { $0 > 0 } ?? false
    }

    /// Called whenever a new item starts, so the library can record history.
    var onItemStarted: ((MediaItem) -> Void)?
    /// Where each video's place is read and kept, so the next play picks up there.
    @ObservationIgnored var progressStore: PlaybackProgressStoring?

    @ObservationIgnored private var playerObservation: NSKeyValueObservation?
    @ObservationIgnored private var externalObservation: NSKeyValueObservation?
    @ObservationIgnored private var itemObservation: NSKeyValueObservation?
    @ObservationIgnored private var itemObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var stallWatch: Task<Void, Never>?
    @ObservationIgnored private var isInterrupted = false
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var sessionObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var commandsInstalled = false
    /// Paused on purpose (the user, or the car unplugged), so the end of a call doesn't restart it.
    @ObservationIgnored private var staysPaused = false
    /// The saved place the item opens at, until it can seek there.
    @ObservationIgnored private var startPoint: Double?
    /// Opening at a saved place: the clock holds there and playback waits for the seek, so the
    /// opening seconds neither flash nor download.
    @ObservationIgnored private var isOpening = false
    @ObservationIgnored private var lastSavedPosition: Double = 0
    /// Off once the playing video is taken out of Continue Watching, so its place isn't kept again.
    @ObservationIgnored private var keepsProgress = true
    /// How often the place is kept while playing.
    private static let saveInterval: Double = 10
    @ObservationIgnored let logger = Logger(subsystem: "com.roadivo", category: "Playback")

    private var index: Int? {
        guard let current else { return nil }
        return queue.firstIndex { $0.id == current.id }
    }

    init() {
        player.allowsExternalPlayback = true
        // Video moves to a car screen or adapter by itself, and sound carries on with the iPhone locked.
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        configureAudioSession()
        observePlayer()
        observeAudioSession()
    }

    // MARK: Intents

    /// Plays `item` from its saved place, or from the beginning when `startingOver`; `queue` is what
    /// next/previous step through (usually the item's group). `origin` is where it was picked.
    func play(_ item: MediaItem, queue: [MediaItem], startingOver: Bool = false, from origin: PlaybackOrigin = .phone) {
        self.origin = origin
        cancelUpNext()
        saveProgress() // The item being left keeps its place.
        activateAudioSession()
        installRemoteCommands()
        staysPaused = false
        // By id: the queue's snapshots may carry older progress than `item`.
        self.queue = queue.contains { $0.id == item.id } ? queue : [item]
        current = item
        duration = nil
        keepsProgress = true
        startPoint = startingOver ? nil : progressStore?.resumePosition(for: item.id)
        isOpening = startPoint != nil
        elapsed = startPoint ?? 0
        lastSavedPosition = elapsed
        status = .loading
        let playerItem = AVPlayerItem(url: item.streamURL)
        observeItem(playerItem)
        if isOpening {
            player.pause() // The rate carries over to the new item; play starts once the seek lands.
        }
        player.replaceCurrentItem(with: playerItem)
        if !isOpening {
            player.play()
        }
        watchForStall()
        updateNowPlaying()
        onItemStarted?(item)
    }

    func togglePlayPause() {
        guard current != nil else { return }
        if case .failed = status {
            resume() // Retries the stream, as the steering wheel's play button does.
        } else if isOpening ? staysPaused : player.timeControlStatus == .paused {
            // While opening at a saved place the player waits paused, but it's on its way to playing.
            resume()
        } else {
            pause()
        }
    }

    /// Plays again; a stream that failed is reloaded, so the steering wheel's play button retries it.
    func resume() {
        guard let current else { return }
        cancelUpNext() // Play at the end starts this video again, so the next one waits.
        staysPaused = false
        if case .failed = status {
            play(current, queue: queue, from: origin)
        } else if isOpening {
            status = .loading // It plays once the seek to the saved place lands.
            watchForStall()
        } else {
            activateAudioSession()
            // At the very end, Play starts the video again instead of doing nothing.
            if let duration, elapsed >= duration - 0.5 {
                player.seek(to: .zero)
            }
            player.play()
        }
    }

    func pause() {
        cancelUpNext()
        staysPaused = true
        player.pause()
        if isOpening {
            status = .paused // The player was already waiting, so no status change will report it.
        }
    }

    func next() {
        guard let index, index + 1 < queue.count else { return }
        play(queue[index + 1], queue: queue, from: origin)
    }

    func previous() {
        guard let index, index > 0 else { return }
        play(queue[index - 1], queue: queue, from: origin)
    }

    /// Jumps to `seconds` into a video with a fixed length (live streams can't seek).
    func seek(to seconds: Double) {
        guard let duration else { return }
        cancelUpNext() // Scrubbing back means staying on this one.
        let target = min(max(0, seconds), duration)
        elapsed = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        updateNowPlaying()
    }

    func updateFavorite(_ isFavorite: Bool, for id: UUID) {
        if current?.id == id {
            current?.isFavorite = isFavorite
        }
        if let position = queue.firstIndex(where: { $0.id == id }) {
            queue[position].isFavorite = isFavorite
        }
    }

    /// Drops deleted items from the queue, and stops if one of them is playing.
    func forget(_ ids: Set<UUID>) {
        if let current, ids.contains(current.id) {
            stop()
            return
        }
        if let upNext, ids.contains(upNext.item.id) {
            cancelUpNext()
        }
        queue.removeAll { ids.contains($0.id) }
        updateCommands()
    }

    func stop() {
        cancelUpNext()
        saveProgress()
        player.pause()
        player.replaceCurrentItem(with: nil)
        stallWatch?.cancel()
        itemObservers = []
        startPoint = nil
        isOpening = false
        current = nil
        origin = .phone
        queue = []
        status = .idle
        duration = nil
        elapsed = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        updateCommands()
        releaseAudio()
    }

    // MARK: Observation

    private func observePlayer() {
        // KVO can fire off the main thread, so the handlers are @Sendable and hop back.
        playerObservation = player.observe(\.timeControlStatus, options: [.new]) { @Sendable [weak self] player, _ in
            let value = player.timeControlStatus
            Task { @MainActor [weak self] in self?.apply(value) }
        }
        let external = \AVPlayer.isExternalPlaybackActive
        externalObservation = player.observe(external, options: [.initial, .new]) { @Sendable [weak self] player, _ in
            let isActive = player.isExternalPlaybackActive
            Task { @MainActor [weak self] in self?.applyExternal(isActive) }
        }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    private func applyExternal(_ isActive: Bool) {
        guard isActive else {
            externalScreen = nil
            return
        }
        let airPlay = AVAudioSession.sharedInstance().currentRoute.outputs.first { $0.portType == .airPlay }
        externalScreen = airPlay?.portName ?? String(appLocalized: "another screen")
    }

    private func observeItem(_ item: AVPlayerItem) {
        // A stream that dies mid-play reports here, not through `status`; the end goes to the next video.
        let center = NotificationCenter.default
        let failed = AVPlayerItem.failedToPlayToEndTimeNotification
        let ended = AVPlayerItem.didPlayToEndTimeNotification
        itemObservers = [
            center.addObserver(forName: failed, object: item, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.fail() }
            },
            center.addObserver(forName: ended, object: item, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reachedEnd() }
            }
        ]
        itemObservation = item.observe(\.status, options: [.new]) { @Sendable [weak self] item, _ in
            let failed = item.status == .failed
            let ready = item.status == .readyToPlay
            let message = item.error?.localizedDescription
            let seconds = item.duration.seconds
            let itemID = ObjectIdentifier(item)
            Task { @MainActor [weak self] in
                guard let self, let current = player.currentItem, ObjectIdentifier(current) == itemID else { return }
                if failed {
                    logger.error("Item failed: \(message ?? "unknown", privacy: .public)")
                    fail()
                    return
                }
                if seconds.isFinite, seconds > 0 {
                    duration = seconds
                    updateNowPlaying()
                }
                if ready {
                    openAtStartPoint()
                    applySubtitles()
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
        // Waiting for the seek to a saved place is still loading.
        case .paused: status = isOpening && !staysPaused ? .loading : .paused
        @unknown default: break
        }
        if value == .paused {
            saveProgress()
        }
        watchForStall()
        updateNowPlaying()
    }

    private func fail() {
        guard current != nil else { return }
        saveProgress() // Where it got to before the signal dropped, for Try Again.
        // No longer opening: Try Again reads the saved place afresh, and Play/Pause reaches it.
        isOpening = false
        startPoint = nil
        stallWatch?.cancel()
        status = .failed(String(appLocalized: "This stream can't be played right now."))
        updateNowPlaying()
    }

    /// A stream stuck loading for 30 s (a tunnel, a dead provider) becomes an error with Try Again.
    private func watchForStall() {
        stallWatch?.cancel()
        guard status == .loading else { return }
        let item = player.currentItem
        stallWatch = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30)) // Cancelled as soon as the status moves on.
            guard !Task.isCancelled, let self, status == .loading, player.currentItem === item else { return }
            fail()
        }
    }

    private func reachedEnd() {
        if let duration {
            elapsed = duration
        }
        saveProgress() // Watched to the end, so it leaves Continue Watching.
        if playsNextAutomatically, let index, index + 1 < queue.count {
            countDown(to: queue[index + 1])
        }
    }
}

// MARK: - Saved places

extension PlaybackController {
    private func tick() {
        guard !isOpening else { return } // Holds at the saved place until the seek lands.
        // Read now, not from the callback: one queued before a switch would carry the last video's time.
        let seconds = player.currentTime().seconds
        elapsed = seconds.isFinite ? seconds : 0
        if status == .playing, abs(elapsed - lastSavedPosition) >= Self.saveInterval {
            saveProgress()
        }
    }

    /// Seeks to the saved place once the item is ready, then plays. A place past the end (the file
    /// changed) plays from the start; a length not known yet doesn't stop the seek.
    private func openAtStartPoint() {
        guard isOpening, let item = player.currentItem else { return }
        let itemID = ObjectIdentifier(item)
        guard let start = startPoint, duration.map({ start < $0 }) ?? true else {
            opened(itemID)
            return
        }
        startPoint = nil
        // A little early rather than late, so nothing is missed, and quicker than an exact frame.
        player.seek(
            to: CMTime(seconds: start, preferredTimescale: 600),
            toleranceBefore: CMTime(seconds: 2, preferredTimescale: 600),
            toleranceAfter: .zero
        ) { @Sendable [weak self] _ in
            Task { @MainActor [weak self] in self?.opened(itemID) }
        }
    }

    /// The seek landed (or was overtaken by the user's own): play, unless paused or a call began
    /// meanwhile (the call's end resumes it).
    private func opened(_ itemID: ObjectIdentifier) {
        guard isOpening, let item = player.currentItem, ObjectIdentifier(item) == itemID else { return }
        isOpening = false
        startPoint = nil
        if case .failed = status {
            return
        }
        if staysPaused || isInterrupted {
            status = .paused
        } else {
            activateAudioSession()
            player.play()
        }
        updateNowPlaying()
    }

    /// Stops keeping the place of `id`, taken out of Continue Watching while it plays.
    func forgetProgress(of id: UUID) {
        if current?.id == id {
            keepsProgress = false
        }
    }

    /// Keeps the playing video's place in the library; only a video with a fixed length has one.
    private func saveProgress() {
        guard keepsProgress, let current, let duration, let progressStore else { return }
        progressStore.saveProgress(PlaybackProgress(position: elapsed, duration: duration), for: current.id)
        lastSavedPosition = elapsed
    }
}

// MARK: - System integration

extension PlaybackController {
    private func observeAudioSession() {
        let center = NotificationCenter.default
        let interruption = AVAudioSession.interruptionNotification
        let routeChange = AVAudioSession.routeChangeNotification
        let background = UIApplication.didEnterBackgroundNotification
        sessionObservers = [
            center.addObserver(forName: interruption, object: nil, queue: .main) { [weak self] note in
                let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
                MainActor.assumeIsolated { self?.interruptionChanged(type: type, options: options) }
            },
            center.addObserver(forName: routeChange, object: nil, queue: .main) { [weak self] note in
                let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                MainActor.assumeIsolated { self?.routeChanged(reason: reason) }
            },
            center.addObserver(forName: background, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.enteredBackground() }
            }
        ]
    }

    /// A call or Siri pauses the video; it carries on afterwards unless it was paused before.
    private func interruptionChanged(type: UInt?, options: UInt?) {
        isInterrupted = type == AVAudioSession.InterruptionType.began.rawValue
        if isInterrupted {
            cancelUpNext() // A call or Siri has the audio; the next video waits for the user.
        }
        guard type == AVAudioSession.InterruptionType.ended.rawValue, let options,
              AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume),
              current != nil, !staysPaused else { return }
        if case .failed = status {
            return
        }
        resume()
    }

    /// Unplugging the car or headphones pauses, as iOS expects, and stays paused. Some car kits
    /// drop out during a call; that isn't an unplug, so the call's end can still resume.
    private func routeChanged(reason: UInt?) {
        applyExternal(player.isExternalPlaybackActive) // The AirPlay screen may have changed.
        guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue, current != nil,
              !isInterrupted else { return }
        pause()
    }

    private func installRemoteCommands() {
        guard !commandsInstalled else { return }
        commandsInstalled = true
        RemoteCommands.install { @Sendable [weak self] command in
            Task { @MainActor [weak self] in self?.perform(command) }
        }
    }
}
