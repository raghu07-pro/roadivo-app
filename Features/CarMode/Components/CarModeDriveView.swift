import SwiftUI

/// Car Mode's Drive View: no video, only the title, how far it is and three big buttons, so a driver
/// is never shown the picture. Exit Drive View brings the video back for passengers or when parked.
struct CarModeDriveView: View {
    let playback: PlaybackController
    let onExitDriveView: () -> Void
    let onExit: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var artworkWidth: CGFloat = 220

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                topBar
                let layout = isLandscape
                    ? AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.lg))
                    : AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.md))
                layout {
                    nowPlaying.frame(maxWidth: .infinity, alignment: .leading)
                    // At large text sizes the title gets the room, so nothing is pushed past the edge.
                    if dynamicTypeSize < .xxLarge {
                        artwork
                    }
                }
            }
            .padding([.horizontal, .top], Spacing.md)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Pinned to the bottom edge, so a long title or a status line never pushes the buttons off screen.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Pinned with the buttons in place of the finished progress, so it can't scroll out of view.
                if let upNext = playback.upNext {
                    UpNextCountdownView(
                        upNext: upNext,
                        onPlayNow: playback.playUpNextNow,
                        onCancel: playback.cancelUpNext,
                        showsArtwork: false,
                        isCompact: true
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    CarModeProgress(playback: playback)
                }
                controls
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, isLandscape ? Spacing.xs : Spacing.md) // Landscape height is scarce.
            // Edge to edge, so what scrolls above goes behind the bar instead of beside it.
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("carMode.drive")
    }

    private var topBar: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: onExitDriveView) {
                Label("Exit Drive View", systemImage: "play.rectangle.fill")
                    .font(Typography.button)
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: 56)
                    .background(.white.opacity(0.14), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint(Text("Shows the video again, for passengers or when parked"))
            .accessibilityIdentifier("carMode.exitDriveView")
            Spacer(minLength: 0)
            RoutePickerButton()
                .frame(width: 56, height: 56)
                .background(.white.opacity(0.14), in: Circle())
            Button(action: onExit) {
                Label("Exit Car Mode", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.bold))
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.14), in: Circle())
            }
            .accessibilityIdentifier("carMode.exit")
        }
    }

    /// The title large and whole, never shrunk to fit; the group, and anything wrong, under it.
    private var nowPlaying: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(playback.current?.title ?? "")
                .font(Typography.hero)
                // Two lines in landscape leave the pinned buttons room; three when upright.
                .lineLimit(isLandscape ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(playback.current?.groupTitle ?? "")
                .font(Typography.sign)
                .foregroundStyle(.white.opacity(0.7))
            status
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder private var artwork: some View {
        if let item = playback.current {
            // The artwork, never the video: a still is all a driver needs to know what's on.
            ArtworkTile(item: item, isWide: true)
                .frame(width: isLandscape ? min(artworkWidth, 280) : nil)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var status: some View {
        if case let .failed(message) = playback.status {
            // Side by side, the message wrapping: stacked, Try Again went behind the buttons on an SE.
            HStack(spacing: Spacing.sm) { failure(message) }
                .padding(.top, Spacing.xs)
        } else if let screen = playback.externalScreen {
            Label("Playing on \(screen)", systemImage: "airplayvideo")
                .font(Typography.secondary.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, Spacing.xs)
        } else if playback.status == .loading {
            ProgressView().tint(.white).padding(.top, Spacing.xs)
        }
    }

    @ViewBuilder
    private func failure(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(Typography.secondary)
            .fixedSize(horizontal: false, vertical: true)
        Button("Try Again", action: playback.resume)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.roadBrand)
            .foregroundStyle(.roadOnBrand)
    }

    /// Previous, a wide Play and Next: the three a driver might reach for, nothing finer.
    private var controls: some View {
        HStack(spacing: Spacing.md) {
            LargeControlButton(
                systemImage: "backward.end.fill",
                label: "Previous channel",
                isEnabled: playback.hasPrevious,
                action: playback.previous
            )
            .accessibilityIdentifier("carMode.drive.previous")
            LargeControlButton(
                systemImage: playback.isPlaying ? "pause.fill" : "play.fill",
                label: playback.isPlaying ? "Pause" : "Play",
                isProminent: true,
                isWide: true,
                action: playback.togglePlayPause
            )
            .accessibilityIdentifier("carMode.drive.playPause")
            LargeControlButton(
                systemImage: "forward.end.fill",
                label: "Next channel",
                isEnabled: playback.hasNext,
                action: playback.next
            )
            .accessibilityIdentifier("carMode.drive.next")
        }
    }
}

#Preview("Landscape", traits: .landscapeLeft) {
    CarModeDriveView(playback: PlaybackController(), onExitDriveView: {}, onExit: {})
        .background(Color.black)
        .environment(\.colorScheme, .dark)
}

#Preview("Largest text") {
    CarModeDriveView(playback: PlaybackController(), onExitDriveView: {}, onExit: {})
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
