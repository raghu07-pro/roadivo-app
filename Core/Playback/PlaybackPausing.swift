/// What voice search needs from the player: quiet while the microphone is on, then carry on.
@MainActor
protocol PlaybackPausing: AnyObject {
    /// True when something was paused and `resume()` should follow.
    func pauseForMicrophone() -> Bool
    func resume()
    /// Lets the car's radio or other apps carry on when nothing here will resume.
    func releaseAudio()
}

extension PlaybackController: PlaybackPausing {}
