import SwiftUI

/// "Up next in 5" after a video ends (DECISIONS 115): the next video's artwork with a ring that drains
/// over the countdown, its title, then Play Now and Cancel across the card. Always on a dark scene.
struct UpNextCountdownView: View {
    let upNext: UpNext
    let onPlayNow: () -> Void
    let onCancel: () -> Void
    /// The next video's artwork under the ring when the card is wide enough; else the ring alone.
    var showsArtwork = true
    /// The title on one line and no group, for a bar pinned above other controls (Drive View).
    var isCompact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var artworkWidth: CGFloat = 148
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 52

    /// At accessibility text sizes the words get the room: no artwork or group, the title on one line.
    private var isTight: Bool {
        isCompact || dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if showsArtwork, !isTight {
                // The artwork only while the title keeps a readable column beside it.
                ViewThatFits(in: .horizontal) {
                    heading(withArtwork: true)
                    heading(withArtwork: false)
                }
            } else {
                heading(withArtwork: false)
            }
            buttons
        }
        .padding(Spacing.md)
        .frame(maxWidth: 520)
        .background(card)
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("upNext.countdown")
    }

    private func heading(withArtwork: Bool) -> some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            countdown(withArtwork: withArtwork)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Up next in \(upNext.secondsLeft)")
                    .font(Typography.data)
                    .textCase(.uppercase)
                    .foregroundStyle(.roadAccent)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(reduceMotion ? nil : .snappy, value: upNext.secondsLeft)
                Text(upNext.item.title)
                    .font(Typography.sign)
                    .foregroundStyle(.white)
                    .lineLimit(isTight ? 1 : 2)
                if !isTight {
                    Text(upNext.item.groupTitle)
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            // Measured at this width when choosing whether the artwork fits; any extra room is the title's.
            .frame(idealWidth: 160, maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Side by side, Play Now taking the room; stacked when a long translation or large text won't fit.
    private var buttons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.sm) {
                playNow
                cancel.fixedSize()
            }
            VStack(spacing: Spacing.sm) {
                playNow
                cancel
            }
        }
    }

    private var playNow: some View {
        PrimaryButton(title: "Play Now", systemImage: "play.fill", action: onPlayNow)
            .accessibilityIdentifier("upNext.playNow")
    }

    /// Play Now's shape and height, in a quiet fill.
    private var cancel: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .font(Typography.button)
                .lineLimit(1)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.lg)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("upNext.cancel")
    }

    /// The ring around a play button, over the artwork or on its own; tapping it plays now.
    private func countdown(withArtwork: Bool) -> some View {
        Button(action: onPlayNow) {
            ZStack {
                if withArtwork {
                    ArtworkTile(item: upNext.item, isWide: true)
                        // Dimmed, so the ring and play read first, even over a channel's initials.
                        .overlay(Color.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .frame(width: min(artworkWidth, 200))
                }
                ring
            }
        }
        .buttonStyle(PressableStyle())
        // Play Now says the same to VoiceOver; this is the bigger target for a finger.
        .accessibilityHidden(true)
    }

    private var ring: some View {
        let size = min(ringSize, 72)
        return ZStack {
            // Near solid, so the play button reads cleanly over any artwork or channel initials.
            Circle()
                .fill(.black.opacity(0.7))
            Circle()
                .stroke(.white.opacity(0.22), lineWidth: 4)
            Circle()
                .trim(from: 0, to: upNext.fraction)
                .stroke(.roadBrandGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // Drains smoothly over each second; with Reduce Motion it steps once a second.
                .animation(reduceMotion ? nil : .linear(duration: 1), value: upNext.secondsLeft)
            Image(systemName: "play.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    /// Frosted over the video, solid with Reduce Transparency; a hairline edge keeps it off the picture.
    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        return ZStack {
            if reduceTransparency {
                shape.fill(Color.black.opacity(0.92))
            } else {
                shape.fill(.ultraThinMaterial)
                shape.fill(Color.black.opacity(0.45))
            }
            shape.strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

#Preview("Full screen") {
    UpNextCountdownView(
        upNext: UpNext(
            item: MediaItem(
                id: UUID(),
                title: "Midnight Courier",
                group: "Movies",
                artworkURL: nil,
                streamURL: URL(fileURLWithPath: "/dev/null"),
                isLocalFile: false,
                isFavorite: false
            ),
            secondsLeft: 3,
            total: 5
        ),
        onPlayNow: {},
        onCancel: {}
    )
    .padding()
    .background(Color.gray)
}

#Preview("Drive View, largest text") {
    UpNextCountdownView(
        upNext: UpNext(
            item: MediaItem(
                id: UUID(),
                title: "Midnight Courier",
                group: "Movies",
                artworkURL: nil,
                streamURL: URL(fileURLWithPath: "/dev/null"),
                isLocalFile: false,
                isFavorite: false
            ),
            secondsLeft: 3,
            total: 5
        ),
        onPlayNow: {},
        onCancel: {},
        showsArtwork: false,
        isCompact: true
    )
    .padding()
    .background(Color.gray)
    .environment(\.dynamicTypeSize, .accessibility3)
}
