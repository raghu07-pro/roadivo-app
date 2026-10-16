import SwiftUI

/// How far the video is, readable from a dashboard mount: a thick bar with the time played and the length
/// (LIVE for a live stream). Seeking stays with ±15 and the steering wheel, not a thin slider.
struct CarModeProgress: View {
    let playback: PlaybackController
    /// Off beside the video, which shows its own LIVE badge.
    var showsLive = true

    @ScaledMetric(relativeTo: .title2) private var barHeight: CGFloat = 8

    var body: some View {
        if let duration = playback.duration {
            let elapsed = min(max(playback.elapsed, 0), duration)
            VStack(spacing: Spacing.xs) {
                Capsule()
                    .fill(.white.opacity(0.18))
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(.roadBrandGradient)
                                .frame(width: max(barHeight, proxy.size.width * elapsed / max(duration, 1)))
                        }
                    }
                    .frame(height: barHeight)
                HStack {
                    Text(PlaybackClock.text(elapsed))
                    Spacer(minLength: Spacing.sm)
                    Text(PlaybackClock.text(duration))
                }
                .font(Typography.readout)
                .foregroundStyle(.white.opacity(0.85))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Playback position"))
            .accessibilityValue(Text("\(PlaybackClock.text(elapsed)) of \(PlaybackClock.text(duration))"))
            .accessibilityIdentifier("carMode.progress")
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
