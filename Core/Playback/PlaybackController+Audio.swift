import AVFoundation

/// Voice search's pause and resume, and skipping, kept beside the controller to keep it short.
extension PlaybackController {
    /// From `elapsed`, which holds the saved place while it opens (the player is still at 0 then).
    func skip(by seconds: Double) {
        seek(to: elapsed + seconds)
    }

    /// Pauses while voice search has the microphone; true when `resume()` should follow.
    func pauseForMicrophone() -> Bool {
        guard current != nil else { return false }
        if isOpeningAtSavedPlace {
            pause() // It would otherwise start once its seek lands, mid-sentence.
            return true
        }
        guard player.timeControlStatus != .paused else { return false }
        player.pause()
        return true
    }

    /// Hands the audio back to the car's radio or other apps, when nothing here is playing.
    func releaseAudio() {
        guard player.timeControlStatus == .paused, !isOpeningAtSavedPlace else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Audio release: \(error.localizedDescription, privacy: .public)")
        }
    }
}
