import SwiftUI

/// 16:9 artwork: a video's own frame, the channel logo, or a title-coloured tile with initials.
/// Always exactly 16:9; everything is drawn in overlays, so a portrait video can't stretch it.
struct ArtworkTile: View {
    let title: String
    let imageURL: URL?
    /// A local video file to take a poster frame from.
    var videoURL: URL?
    var isLive = false
    var cornerRadius: CGFloat = Radius.md

    @State private var poster: UIImage?

    init(title: String, imageURL: URL?, videoURL: URL? = nil, isLive: Bool = false, cornerRadius: CGFloat = Radius.md) {
        self.title = title
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.isLive = isLive
        self.cornerRadius = cornerRadius
        _poster = State(initialValue: videoURL.flatMap(VideoThumbnails.shared.cachedImage(for:)))
    }

    var body: some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                ZStack {
                    Palette.placeholderGradient(for: title)
                    Text(title.initials)
                        .font(Typography.screenTitle)
                        .foregroundStyle(.white.opacity(0.9))
                        .minimumScaleFactor(0.5)
                        .padding(Spacing.xs)
                }
            }
            .overlay {
                if let poster {
                    Image(uiImage: poster)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else if let imageURL {
                    AsyncImage(url: imageURL, transaction: Transaction(animation: .easeIn(duration: 0.2))) { phase in
                        if let image = phase.image {
                            ZStack {
                                Color.black.opacity(0.35)
                                image.resizable().scaledToFit().padding(Spacing.sm)
                            }
                        }
                    }
                }
            }
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
                withAnimation(.easeIn(duration: 0.2)) { poster = image }
            }
            .accessibilityHidden(true)
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
