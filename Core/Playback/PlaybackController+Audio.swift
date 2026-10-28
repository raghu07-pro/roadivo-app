import AVFoundation

/// The audio session, voice search's pause and resume, and skipping, kept beside the controller to keep it short.
extension PlaybackController {
    /// From `elapsed`, which holds the saved place while it opens (the player is still at 0 then).
    func skip(by seconds: Double) {
        seek(to: elapsed + seconds)
    }

    /// Pauses while voice search has the microphone; true when `resume()` should follow.
    func pauseForMicrophone() -> Bool {
        guard current != nil else { return false }
        if upNext != nil {
            cancelUpNext() // The next video would otherwise start mid-sentence and cut the dictation off.
            return false
        }
        if isOpeningAtSavedPlace {
            pause() // It would otherwise start once its seek lands, mid-sentence.
            return true
        }
        guard player.timeControlStatus != .paused else { return false }
        player.pause()
        return true
    }

    /// Set at launch too, so CarPlay and the lock screen treat PlayCarTV as a video player from the start.
    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
        } catch {
            logger.error("Audio category: \(error.localizedDescription, privacy: .public)")
        }
    }

    func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        // Set again only after voice search borrowed it: setting it while active can stall the screen (Xcode 27).
        let isSet = session.category == .playback && session.mode == .moviePlayback
            && session.routeSharingPolicy == .longFormVideo
        if !isSet {
            configureAudioSession()
        }
        // The iOS 27 SDK's activate(options:) doesn't hold the main thread; older SDKs and iOS keep setActive.
        #if compiler(>=6.4)
            if #available(iOS 27, *) {
                session.activate(options: []) { [weak self, logger] isActive, error in
                    if let error {
                        logger.error("Audio session: \(error.localizedDescription, privacy: .public)")
                    }
                    if isActive {
                        Task { @MainActor [weak self] in self?.restartIfStuckAtStart() }
                    }
                }
                return
            }
        #endif
        do {
            try session.setActive(true)
        } catch {
            logger.error("Audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Hands the audio back to the car's radio or other apps, when nothing here is playing.
    func releaseAudio() {
        guard player.timeControlStatus == .paused, !isOpeningAtSavedPlace else { return }
        let session = AVAudioSession.sharedInstance()
        #if compiler(>=6.4)
            if #available(iOS 27, *) {
                session.deactivate(options: .notifyOthersOnDeactivation) { [weak self, logger] _, error in
                    if let error {
                        logger.error("Audio release: \(error.localizedDescription, privacy: .public)")
                    }
                    // A pick made while this finished would otherwise play into a released session.
                    Task { @MainActor [weak self] in self?.reactivateIfPlaying() }
                }
                return
            }
        #endif
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Audio release: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The first play after launch can say it's playing yet sit at 0:00 (the car's trace, 2026-10-26; DECISIONS 168);
    /// Pause and Play started it every time, so a moment in, and again later, a player still there gets the same.
    func watchStart() {
        let item = player.currentItem
        Task { [weak self] in
            for delay in [Duration.milliseconds(1500), .milliseconds(2500)] {
                try? await Task.sleep(for: delay) // Its checks below stand in for cancelling.
                guard let self, player.currentItem === item else { return }
                restartIfStuckAtStart()
            }
        }
    }

    /// Only a player claiming to play while still at its start: a stream still buffering says it's waiting instead.
    func restartIfStuckAtStart() {
        guard current != nil, !isOpeningAtSavedPlace, player.timeControlStatus == .playing,
              player.currentItem?.status == .readyToPlay, player.currentTime().seconds < 0.1 else { return }
        player.pause()
        player.play()
    }

    /// The session was released just as something began playing: take it back.
    func reactivateIfPlaying() {
        guard current != nil, player.rate > 0 || isOpeningAtSavedPlace else { return }
        activateAudioSession()
    }
}
