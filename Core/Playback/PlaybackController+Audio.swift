import AVFoundation

/// Voice search's pause and resume, and skipping, kept beside the controller to keep it short.
extension PlaybackController {
    func skip(by seconds: Double) {
        seek(to: player.currentTime().seconds + seconds)
    }

    /// Pauses while voice search has the microphone; true when `resume()` should follow.
    func pauseForMicrophone() -> Bool {
        guard current != nil, player.timeControlStatus != .paused else { return false }
        player.pause()
        return true
    }

    /// Hands the audio back to the car's radio or other apps, when nothing here is playing.
    func releaseAudio() {
        guard player.timeControlStatus == .paused else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Audio release: \(error.localizedDescription, privacy: .public)")
        }
    }
}
