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
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            requestOrientation(.landscape)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            requestOrientation(.portrait)
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

    private func requestOrientation(_ mask: UIInterfaceOrientationMask) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
    }
}
