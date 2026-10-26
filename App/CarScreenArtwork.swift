#if DEBUG
    import SwiftUI

    /// A video's picture on the car's screen, filling its frame: its still, a logo on the surface, or its initial on
    /// the cover colours; how much was watched along the bottom (DECISIONS 167).
    struct CarScreenArtwork: View {
        let media: MediaItem
        let model: CarScreenModel
        var showsProgress = true
        @State private var picture: UIImage?

        var body: some View {
            Color.clear
                .overlay { content }
                .overlay(alignment: .bottom) {
                    if showsProgress, let progress = media.progress {
                        WatchProgressBar(fraction: progress.fraction)
                    }
                }
                .clipped()
                .task(id: media.id) {
                    picture = model.artwork.picture(for: media) { picture = $0 }
                }
                .accessibilityHidden(true)
        }

        @ViewBuilder private var content: some View {
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
        }

        private var initial: String {
            media.title.first.map { String($0).uppercased() } ?? ""
        }
    }
#endif
