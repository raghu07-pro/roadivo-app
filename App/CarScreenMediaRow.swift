#if DEBUG
    import SwiftUI

    /// A video in a car list, as a card: its artwork, title and group, how much was watched, and whether it's playing.
    struct CarScreenMediaRow: View {
        let media: MediaItem
        let model: CarScreenModel
        let action: () -> Void
        @State private var picture: UIImage?

        var body: some View {
            Button(action: action) {
                HStack(spacing: Spacing.md) {
                    artwork
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(media.title)
                            .font(Typography.sign)
                            .lineLimit(1)
                        Text(media.groupTitle)
                            .font(Typography.secondary)
                            .foregroundStyle(.roadMuted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if model.playingID == media.id {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.headline)
                            .foregroundStyle(.roadAccent)
                            .accessibilityLabel(Text(app: "Now playing: \(media.title)"))
                    }
                }
                .padding(Spacing.xs)
                .padding(.trailing, Spacing.sm)
                .frame(minHeight: 72)
            }
            .buttonStyle(CarCardStyle())
            .task(id: media.id) {
                picture = model.artwork.picture(for: media) { picture = $0 }
            }
        }

        private var artwork: some View {
            ZStack(alignment: .bottom) {
                if let picture {
                    Image(uiImage: picture)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: media.isLocalFile ? "film" : "play.tv")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Palette.placeholderGradient(for: media.title))
                }
                if let progress = media.progress {
                    WatchProgressBar(fraction: progress.fraction)
                }
            }
            .frame(width: 104, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .accessibilityHidden(true)
        }
    }
#endif
