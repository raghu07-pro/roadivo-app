import MediaPlayer

/// What the lock screen, Control Center, CarPlay and the steering wheel show and send.
extension PlaybackController {
    func perform(_ command: RemoteCommands.Command) {
        switch command {
        case .toggle: togglePlayPause()
        case .play: resume()
        case .pause: pause()
        // Steering-wheel "next track" switches channel.
        case .next: next()
        case .previous: previous()
        case let .seek(seconds): seek(to: seconds)
        }
    }

    func updateNowPlaying() {
        updateCommands()
        guard let current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.title,
            MPMediaItemPropertyArtist: current.groupTitle,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: duration == nil,
            MPNowPlayingInfoPropertyPlaybackRate: status == .playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed
        ]
        if let duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Lock-screen and car buttons only look live when they'd do something.
    func updateCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.nextTrackCommand.isEnabled = hasNext
        center.previousTrackCommand.isEnabled = hasPrevious
        center.changePlaybackPositionCommand.isEnabled = duration != nil
        for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand] {
            command.isEnabled = current != nil
        }
    }
}

/// Lock screen, CarPlay and steering-wheel buttons. iOS may call these off the main thread, so
/// they're made outside the main actor and the player hops back.
enum RemoteCommands {
    enum Command {
        case toggle, play, pause, next, previous
        case seek(Double)
    }

    static func install(_ perform: @escaping @Sendable (Command) -> Void) {
        let center = MPRemoteCommandCenter.shared()
        let targets: [(MPRemoteCommand, Command)] = [
            (center.togglePlayPauseCommand, .toggle),
            (center.playCommand, .play),
            (center.pauseCommand, .pause),
            (center.nextTrackCommand, .next),
            (center.previousTrackCommand, .previous)
        ]
        for (remote, command) in targets {
            remote.addTarget { _ in
                perform(command)
                return .success
            }
        }
        // Dragging the progress bar on the lock screen or CarPlay.
        center.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            perform(.seek(event.positionTime))
            return .success
        }
    }
}
