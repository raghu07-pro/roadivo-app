import SwiftUI

/// Artwork (16:9, or 2:3 for a poster): the video's frame or the image once loaded, a shimmering
/// skeleton while loading, and the coloured cover with initials only when there's none (or it failed).
struct ArtworkTile: View {
    let title: String
    let imageURL: URL?
    /// A local video file to take a poster frame from.
    var videoURL: URL?
    var isLive = false
    var cornerRadius: CGFloat = Radius.md
    /// Width over height.
    var aspectRatio: CGFloat = 16 / 9
    /// A photo or poster fills the frame; a logo (often transparent) sits on the cover instead.
    var fillsFrame = false

    @State private var poster: UIImage?
    /// The video's frame couldn't be read, so the cover stands in.
    @State private var posterFailed = false
    /// The logo is taking too long (a dead host makes AsyncImage wait a minute), so the cover stands in.
    @State private var logoIsSlow = false

    private static let logoPatience: Duration = .seconds(6)

    init(
        title: String,
        imageURL: URL?,
        videoURL: URL? = nil,
        isLive: Bool = false,
        cornerRadius: CGFloat = Radius.md,
        aspectRatio: CGFloat = 16 / 9,
        fillsFrame: Bool = false
    ) {
        self.title = title
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.isLive = isLive
        self.cornerRadius = cornerRadius
        self.aspectRatio = aspectRatio
        self.fillsFrame = fillsFrame
        _poster = State(initialValue: videoURL.flatMap(VideoThumbnails.shared.cachedImage(for:)))
    }

    var body: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay { artwork }
            .overlay(alignment: .bottomTrailing) {
                if poster != nil {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(Spacing.xs)
                }
            }
            .overlay(alignment: .topLeading) {
                if isLive {
                    LiveBadge().padding(Spacing.xs)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .task(id: videoURL) {
                guard let videoURL, poster == nil else { return }
                let image = await VideoThumbnails.shared.image(for: videoURL)
                withAnimation(.easeIn(duration: 0.25)) {
                    poster = image
                    posterFailed = image == nil
                }
            }
            .task(id: imageURL) {
                logoIsSlow = false
                guard imageURL != nil else { return }
                // Cancelled with the tile or a new logo; a logo that arrives later still replaces the cover.
                try? await Task.sleep(for: Self.logoPatience)
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.25)) { logoIsSlow = true }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder private var artwork: some View {
        if let poster {
            Image(uiImage: poster)
                .resizable()
                .scaledToFill()
                .transition(.opacity)
        } else if videoURL != nil, !posterFailed {
            SkeletonView()
        } else if let imageURL {
            AsyncImage(url: imageURL, transaction: Transaction(animation: .easeIn(duration: 0.25))) { phase in
                switch phase {
                case let .success(image):
                    if fillsFrame {
                        image.resizable().scaledToFill().transition(.opacity)
                    } else {
                        // Logos are often transparent, so they sit on the cover without its initials.
                        ZStack {
                            Palette.placeholderGradient(for: title)
                            Color.black.opacity(0.35)
                            image.resizable().scaledToFit().padding(Spacing.sm)
                        }
                        .transition(.opacity)
                    }
                case .empty:
                    if logoIsSlow {
                        cover
                    } else {
                        SkeletonView()
                    }
                default:
                    cover
                }
            }
        } else {
            cover
        }
    }

    /// The stand-in when there's no artwork: the title's colours and its initials.
    private var cover: some View {
        ZStack {
            Palette.placeholderGradient(for: title)
            Text(title.initials)
                .font(Typography.screenTitle)
                .foregroundStyle(.white.opacity(0.9))
                .minimumScaleFactor(0.5)
                .padding(Spacing.xs)
        }
    }
}

struct LiveBadge: View {
    var body: some View {
        Text("LIVE")
            .font(Typography.badge)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.roadLive, in: Capsule())
    }
}

#Preview {
    HStack {
        ArtworkTile(title: "Coastal Echoes", imageURL: nil, isLive: true)
        ArtworkTile(title: "Highway Stop", imageURL: nil)
    }
    .padding()
}
