#if DEBUG
    import SwiftUI

    /// A video in a car list: its artwork, title and group, how much was watched, and whether it's playing.
    struct CarScreenMediaRow: View {
        let media: MediaItem
        let model: CarScreenModel
        let action: () -> Void
        @State private var picture: UIImage?

        var body: some View {
            Button(action: action) {
                HStack(spacing: Spacing.sm) {
                    artwork
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(media.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(media.groupTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if model.playingID == media.id {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(Color.roadBrand)
                            .accessibilityLabel(Text(app: "Now playing: \(media.title)"))
                    }
                }
                .padding(Spacing.xs)
                .frame(minHeight: 64)
            }
            .buttonStyle(CarKeyStyle())
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
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.roadSurface)
                }
                if let progress = media.progress {
                    WatchProgressBar(fraction: progress.fraction)
                }
            }
            .frame(width: 96, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            .accessibilityHidden(true)
        }
    }
#endif
