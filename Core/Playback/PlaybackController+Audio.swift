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

    /// Set at launch too, so CarPlay and the lock screen treat Roadivo as a video player from the start.
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
                session.activate(options: []) { [logger] _, error in
                    if let error {
                        logger.error("Audio session: \(error.localizedDescription, privacy: .public)")
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
                session.deactivate(options: .notifyOthersOnDeactivation) { [logger] _, error in
                    if let error {
                        logger.error("Audio release: \(error.localizedDescription, privacy: .public)")
                    }
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
}
