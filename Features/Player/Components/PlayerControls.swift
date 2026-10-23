import SwiftUI

/// The controls drawn on the video: minimise, title, favourite and close along the top;
/// rotation lock on the left; play/pause, times, scrubber and full screen along the bottom.
struct PlayerControls: View {
    let playback: PlaybackController
    let title: String
    let isFavorite: Bool
    let isLandscape: Bool
    let isRotationLocked: Bool
    let onMinimize: () -> Void
    let onFavorite: () -> Void
    let onClose: () -> Void
    let onRotationLock: () -> Void
    let onFullScreen: () -> Void
    /// Any touch on a control keeps the controls up a little longer.
    let onInteraction: () -> Void

    @State private var scrubbing: Double?
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
            HStack {
                button(
                    isRotationLocked ? "lock.rotation" : "lock.rotation.open",
                    label: isRotationLocked ? "Unlock rotation" : "Lock rotation",
                    identifier: "player.rotationLock",
                    isOn: isRotationLocked,
                    action: onRotationLock
                )
                Spacer()
            }
            Spacer(minLength: 0)
            bottomBar
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .foregroundStyle(.white)
        .background {
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                Color.clear
                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
        }
        .environment(\.colorScheme, .dark)
    }

    private var topBar: some View {
        HStack(spacing: Spacing.xxs) {
            button("chevron.down", label: "Minimize player", identifier: "player.minimize", action: onMinimize)
            Text(title) // Two lines, so larger text wraps a long title rather than cutting it off.
                .font(Typography.cardTitle)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Button {
                onFavorite()
                onInteraction()
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isFavorite ? Color.roadLive : .white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
            .dynamicTypeSize(...Self.largestIcon)
            .accessibilityShowsLargeContentViewer()
            .accessibilityLabel(isFavorite ? Text("Remove from Favorites") : Text("Add to Favorites"))
            .accessibilityIdentifier("player.favorite")
            button("xmark", label: "Close player", identifier: "player.close", action: onClose)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: Spacing.xs) {
            button(
                playback.isPlaying ? "pause.fill" : "play.fill",
                label: playback.isPlaying ? "Pause" : "Play",
                identifier: "player.playPause",
                action: playback.togglePlayPause
            )
            if let duration = playback.duration {
                let position = scrubbing ?? playback.elapsed
                Text(Self.clock(position))
                    .font(Typography.caption.monospacedDigit())
                    .accessibilityHidden(true)
                Slider(value: Binding(get: { position }, set: { scrub(to: $0) }), in: 0...max(duration, 1)) { editing in
                    isDragging = editing
                    onInteraction()
                    if !editing, let target = scrubbing {
                        playback.seek(to: target)
                        scrubbing = nil
                    }
                }
                .tint(.roadBrand)
                .accessibilityLabel(Text("Playback position"))
                .accessibilityValue(Text("\(Self.clock(position)) of \(Self.clock(duration))"))
                .accessibilityIdentifier("player.scrubber")
                Text(Self.clock(duration))
                    .font(Typography.caption.monospacedDigit())
                    .accessibilityHidden(true)
            } else {
                if playback.current != nil, playback.status == .playing {
                    LiveBadge()
                }
                Spacer(minLength: 0)
            }
            button(
                isLandscape ? "rectangle.portrait.rotate" : "rectangle.landscape.rotate",
                label: isLandscape ? "Exit full screen" : "Full screen",
                identifier: "player.fullScreen",
                action: onFullScreen
            )
        }
    }

    /// A drag seeks when it ends; VoiceOver's swipe up or down seeks straight away.
    private func scrub(to seconds: Double) {
        onInteraction() // Keeps the controls up for the whole drag.
        if isDragging {
            scrubbing = seconds
        } else {
            playback.seek(to: seconds)
        }
    }

    private func button(
        _ symbol: String,
        label: LocalizedStringKey,
        identifier: String,
        isOn: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            onInteraction()
        } label: {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(isOn ? 0.25 : 0), in: Circle())
                .contentShape(Circle())
        }
        .dynamicTypeSize(...Self.largestIcon)
        .accessibilityShowsLargeContentViewer()
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }

    /// Like the system's bars, the icons stop growing here so they never overlap; a long press shows them
    /// enlarged (Large Content Viewer). The title and times keep scaling.
    private static let largestIcon = DynamicTypeSize.xxxLarge

    /// "0:07", "12:40" or "1:02:05".
    static func clock(_ seconds: Double) -> String {
        PlaybackClock.text(seconds)
    }
}
