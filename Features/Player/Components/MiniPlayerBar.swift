import SwiftUI

/// Floating now-playing bar above the tab bar: live video thumbnail, title and
/// controls. Tap to return to the full player. A video on the car shows a car instead of its picture (DECISIONS 165).
struct MiniPlayerBar: View {
    let playback: PlaybackController
    let onExpand: () -> Void

    @ScaledMetric(relativeTo: .body) private var thumbnailWidth: CGFloat = 88

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: onExpand) {
                HStack(spacing: Spacing.sm) {
                    Group {
                        if playback.origin == .car {
                            Image(systemName: "car.fill")
                                .font(.title3)
                                .foregroundStyle(.roadOnBrand)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.roadBrandGradient)
                        } else {
                            VideoSurface(player: playback.player, gravity: .resizeAspectFill)
                        }
                    }
                    .frame(width: min(thumbnailWidth, 140), height: min(thumbnailWidth, 140) * 9 / 16)
                    .overlay(alignment: .bottom) {
                        // How far in, as Music's and YouTube's mini players show it.
                        if let duration = playback.duration, duration > 0 {
                            WatchProgressBar(fraction: playback.elapsed / duration)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playback.current?.title ?? "")
                            .font(Typography.cardTitle)
                            .lineLimit(1)
                        // The countdown, after a video ends; the full player has its Play Now and Cancel.
                        Group {
                            if let upNext = playback.upNext {
                                Text("Up next in \(upNext.secondsLeft)")
                            } else if playback.origin == .car {
                                Text("Playing on your car display")
                            } else {
                                Text(playback.current?.groupTitle ?? "")
                            }
                        }
                        .font(Typography.caption)
                        .foregroundStyle(.roadMuted)
                        .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Minimised, the countdown is only this line, so VoiceOver reads it here.
            .accessibilityLabel(
                playback.upNext.map { Text("Up next: \($0.item.title)") }
                    ?? Text("Now playing: \(playback.current?.title ?? "")")
            )
            .accessibilityHint(Text("Opens the player"))
            .accessibilityIdentifier("miniPlayer.expand")

            Button(action: playback.togglePlayPause) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(playback.isPlaying ? Text("Pause") : Text("Play"))
            .accessibilityIdentifier(playback.isPlaying ? "miniPlayer.pause" : "miniPlayer.play")

            Button(action: playback.stop) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("Stop playback"))
            .accessibilityIdentifier("miniPlayer.close")
        }
        .foregroundStyle(.primary)
        .padding(Spacing.xs)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
    }
}
