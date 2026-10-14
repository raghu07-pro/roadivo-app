import SwiftUI
import UIKit

/// Landscape dashboard layout for passengers: the video and oversized controls. Steering-wheel
/// buttons also work (PlaybackController's remote commands).
struct CarModeView: View {
    let playback: PlaybackController
    let onExit: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        let isLandscape = verticalSizeClass == .compact
        let layout = isLandscape
            ? AnyLayout(HStackLayout(spacing: Spacing.lg))
            : AnyLayout(VStackLayout(spacing: Spacing.lg))
        layout {
            VideoSurface(player: playback.player)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .overlay { status }
                .overlay(alignment: .topLeading) {
                    if playback.isLive, playback.status == .playing {
                        LiveBadge().padding(Spacing.sm)
                    }
                }
                .accessibilityLabel(Text("Video"))
            ScrollView {
                controls
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: isLandscape ? 300 : .infinity)
        }
        .padding(Spacing.md)
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            OrientationLock.shared.hold(.landscape)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            OrientationLock.shared.reset()
        }
    }

    /// Loading, a failed stream (with Try Again) or the screen the video went to, never a silent black box.
    @ViewBuilder private var status: some View {
        if case let .failed(message) = playback.status {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill").font(.title)
                Text(message).font(Typography.secondary).multilineTextAlignment(.center)
                Button("Try Again", action: playback.resume)
                    .buttonStyle(.borderedProminent)
                    .tint(.roadBrand)
                    .foregroundStyle(.roadOnBrand)
            }
            .foregroundStyle(.white)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black.opacity(0.75))
        } else if let screen = playback.externalScreen {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "airplayvideo").font(.largeTitle)
                Text("Playing on \(screen)")
                    .font(Typography.secondary.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white.opacity(0.85))
            .accessibilityElement(children: .combine)
        } else if playback.status == .loading {
            ProgressView().controlSize(.large).tint(.white)
        }
    }

    private var controls: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Button(action: onExit) {
                    Label("Exit Car Mode", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .font(.title3.weight(.bold))
                        .frame(width: 56, height: 56)
                        .background(.white.opacity(0.14), in: Circle())
                }
                .accessibilityIdentifier("carMode.exit")
                Spacer()
                RoutePickerButton()
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.14), in: Circle())
            }

            VStack(spacing: Spacing.xxs) {
                Text(playback.current?.title ?? "")
                    .font(Typography.screenTitle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(playback.current?.groupTitle ?? "")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)

            HStack(spacing: Spacing.md) {
                LargeControlButton(
                    systemImage: "backward.end.fill",
                    label: "Previous channel",
                    isEnabled: playback.hasPrevious,
                    action: playback.previous
                )
                LargeControlButton(
                    systemImage: playback.isPlaying ? "pause.fill" : "play.fill",
                    label: playback.isPlaying ? "Pause" : "Play",
                    isProminent: true,
                    action: playback.togglePlayPause
                )
                LargeControlButton(
                    systemImage: "forward.end.fill",
                    label: "Next channel",
                    isEnabled: playback.hasNext,
                    action: playback.next
                )
            }

            if !playback.isLive {
                HStack(spacing: Spacing.md) {
                    LargeControlButton(systemImage: "gobackward.15", label: "Back 15 seconds") {
                        playback.skip(by: -15)
                    }
                    LargeControlButton(systemImage: "goforward.15", label: "Forward 15 seconds") {
                        playback.skip(by: 15)
                    }
                }
            }
        }
    }
}
