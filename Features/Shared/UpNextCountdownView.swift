import SwiftUI

/// "Up next in 5" after a video ends (DECISIONS 115): the next video's artwork with a ring that drains
/// over the countdown, its title, Play Now and Cancel. Over the video, so always on a dark scene.
struct UpNextCountdownView: View {
    let upNext: UpNext
    let onPlayNow: () -> Void
    let onCancel: () -> Void
    /// The next video's artwork under the ring, where there's room (full screen, Car Mode); else the ring alone.
    var showsArtwork = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .body) private var artworkWidth: CGFloat = 148
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 52

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            countdown
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Up next in \(upNext.secondsLeft)")
                    .font(Typography.data)
                    .textCase(.uppercase)
                    .foregroundStyle(.roadAccent)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(reduceMotion ? nil : .snappy, value: upNext.secondsLeft)
                VStack(alignment: .leading, spacing: 2) {
                    Text(upNext.item.title)
                        .font(Typography.sign)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(upNext.item.groupTitle)
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                HStack(spacing: Spacing.sm) {
                    PrimaryButton(title: "Play Now", systemImage: "play.fill", isCompact: true, action: onPlayNow)
                        .accessibilityIdentifier("upNext.playNow")
                    // Play Now's shape and height, in a quiet fill, so the pair reads as one row.
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(Typography.button)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.lg)
                            .frame(minHeight: 54)
                            .background(
                                .white.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("upNext.cancel")
                }
                .padding(.top, Spacing.xxs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.md)
        .frame(maxWidth: 520)
        .background(card)
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("upNext.countdown")
        .onAppear {
            AccessibilityNotification.Announcement(String(appLocalized: "Up next: \(upNext.item.title)")).post()
        }
    }

    /// The ring around a play button, over the artwork or on its own; tapping it plays now.
    private var countdown: some View {
        Button(action: onPlayNow) {
            ZStack {
                if showsArtwork {
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
        // Play Now beside it says the same to VoiceOver; this is the bigger target for a finger.
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

#Preview("Upright player, largest text") {
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
        showsArtwork: false
    )
    .padding()
    .background(Color.gray)
    .environment(\.dynamicTypeSize, .accessibility3)
}
