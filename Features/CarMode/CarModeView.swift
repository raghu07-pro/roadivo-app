import SwiftUI
import UIKit

/// Landscape dashboard layout: the video with oversized controls for passengers or when parked, or
/// Drive View (no video) for the driver. Steering-wheel buttons also work (remote commands).
struct CarModeView: View {
    let playback: PlaybackController
    /// No video, big controls (DECISIONS 114); remembered for the next time Car Mode opens.
    @Binding var isDriveView: Bool
    let onExit: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        // A ZStack, not a Group: a Group's onAppear and onDisappear fire on every switch between the two
        // views, which let the screen lock and the iPhone turn upright in Drive View.
        ZStack {
            if isDriveView {
                CarModeDriveView(playback: playback, onExitDriveView: { isDriveView = false }, onExit: onExit)
            } else {
                videoLayout
            }
        }
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

    @ViewBuilder private var videoLayout: some View {
        let isLandscape = verticalSizeClass == .compact
        let layout = isLandscape
            ? AnyLayout(HStackLayout(spacing: Spacing.lg))
            : AnyLayout(VStackLayout(spacing: Spacing.lg))
        layout {
            // The progress under the video, so the controls beside it still fit on a landscape iPhone.
            VStack(spacing: Spacing.sm) {
                VideoSurface(player: playback.player, gravity: playback.videoGravity)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    .overlay { status }
                    .overlay(alignment: .topLeading) {
                        if playback.isLive, playback.status == .playing {
                            LiveBadge().padding(Spacing.sm)
                        }
                    }
                    .accessibilityLabel(Text("Video"))
                    .accessibilityIdentifier("carMode.video")
                CarModeProgress(playback: playback, showsLive: false)
            }
            ScrollView {
                controls
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: isLandscape ? 300 : .infinity)
        }
        .padding(Spacing.md)
    }

    /// Loading, a failed stream (with Try Again) or the screen the video went to, never a silent black box.
    @ViewBuilder private var status: some View {
        if case let .failed(message) = playback.status {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill").font(.title)
                Text(message).font(Typography.secondary).multilineTextAlignment(.center)
                Button("Try Again", action: playback.resume)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
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
                driveViewButton
                Spacer()
                RoutePickerButton()
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.14), in: Circle())
            }

            VStack(spacing: Spacing.xxs) {
                // Wraps rather than shrinking, so it stays readable from the mount.
                Text(playback.current?.title ?? "")
                    .font(Typography.screenTitle)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
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

    /// Into Drive View: the label while it fits beside the other buttons, else the wheel alone.
    private var driveViewButton: some View {
        Button {
            isDriveView = true
        } label: {
            ViewThatFits(in: .horizontal) {
                Label("Drive View", systemImage: "steeringwheel")
                    .font(Typography.button)
                    .padding(.horizontal, Spacing.md)
                    .frame(height: 56)
                    .background(.white.opacity(0.14), in: Capsule())
                Label("Drive View", systemImage: "steeringwheel")
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.bold))
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.14), in: Circle())
            }
            .contentShape(Capsule())
        }
        .foregroundStyle(.white)
        .accessibilityHint(Text("Hides the video and keeps big controls, for the driver"))
        .accessibilityIdentifier("carMode.driveView")
    }
}
