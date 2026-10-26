#if DEBUG
    import SwiftUI

    /// A video on the car's search results, as CarTV's: a square picture, or its initial on the theme's cover colours,
    /// with its title below.
    struct CarScreenMediaTile: View {
        let media: MediaItem
        let model: CarScreenModel
        let action: () -> Void
        @State private var picture: UIImage?

        /// The tile's side, in points.
        static let side: CGFloat = 168

        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    artwork
                    Text(media.title)
                        .font(Typography.sign)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(width: Self.side)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(media.title))
            .task(id: media.id) {
                picture = model.artwork.picture(for: media) { picture = $0 }
            }
        }

        private var artwork: some View {
            ZStack(alignment: .bottom) {
                if let picture {
                    if media.artwork == .logo, !media.isLocalFile {
                        // A logo (often transparent) sits on the surface, as on the iPhone.
                        Color.roadSurface.overlay {
                            Image(uiImage: picture)
                                .resizable()
                                .scaledToFit()
                                .padding(Spacing.md)
                        }
                    } else {
                        Image(uiImage: picture)
                            .resizable()
                            .scaledToFill()
                    }
                } else {
                    Palette.placeholderGradient(for: media.title)
                        .overlay {
                            Text(initial)
                                .font(Typography.hero)
                                .foregroundStyle(.white)
                        }
                }
                if let progress = media.progress {
                    WatchProgressBar(fraction: progress.fraction)
                }
            }
            .frame(width: Self.side, height: Self.side)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(alignment: .topLeading) {
                // As CarTV's "Playing" on the channel that's on.
                if model.playingID == media.id {
                    Text(app: "Playing")
                        .font(Typography.cardTitle)
                        .foregroundStyle(.roadOnBrand)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .background(
                            .roadBrandGradient,
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        )
                        .padding(Spacing.xs)
                }
            }
        }

        private var initial: String {
            media.title.first.map { String($0).uppercased() } ?? ""
        }
    }
#endif
