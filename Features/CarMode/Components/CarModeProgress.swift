import SwiftUI

/// How far the video is, readable from a dashboard mount: a thick bar with the time played and the length
/// (LIVE for a live stream). Seeking stays with ±15 and the steering wheel, not a thin slider.
struct CarModeProgress: View {
    let playback: PlaybackController
    /// Off beside the video, which shows its own LIVE badge.
    var showsLive = true

    var body: some View {
        if let duration = playback.duration {
            PlaybackProgressBar(elapsed: playback.elapsed, duration: duration)
        } else if showsLive, playback.isLive, playback.status == .playing {
            LiveBadge()
        }
    }
}

#Preview("Nothing loaded") {
    CarModeProgress(playback: PlaybackController())
        .padding()
        .background(Color.black)
        .environment(\.colorScheme, .dark)
}
