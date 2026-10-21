import UIKit

/// Each CarPlay row's picture: a channel logo as a solid tile (`SiteIconTile`, so it reads on the car's dark list),
/// a server's still or poster, or a frame of a video on this iPhone. Fetched once, kept in memory (DECISIONS 141).
@MainActor
final class CarPlayArtwork {
    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    /// Pictures that couldn't be fetched aren't asked for again on every redraw.
    private var failed: Set<URL> = []

    init() {
        cache.countLimit = 300
    }

    /// The picture now if it's ready; otherwise nil, and `ready` gets it once fetched.
    func picture(for media: MediaItem, ready: @escaping @MainActor (UIImage) -> Void) -> UIImage? {
        guard let key = media.isLocalFile ? media.streamURL : media.artworkURL, !failed.contains(key) else {
            return nil
        }
        if let image = cache.object(forKey: key as NSURL) {
            return image
        }
        Task {
            if let image = await load(key, for: media) {
                ready(image)
            }
        }
        return nil
    }

    private func load(_ key: URL, for media: MediaItem) async -> UIImage? {
        if let running = inFlight[key] {
            return await running.value
        }
        let task = Task { await Self.make(for: media) }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image {
            cache.setObject(image, forKey: key as NSURL)
        } else {
            failed.insert(key)
        }
        return image
    }
}

private extension CarPlayArtwork {
    /// Off the main thread: the download and the pixel work for a logo's tile.
    nonisolated static func make(for media: MediaItem) async -> UIImage? {
        if media.isLocalFile {
            return await VideoThumbnails.shared.image(for: media.streamURL).map(fitted)
        }
        // A logo that can't be fetched leaves the row's symbol, as on the iPhone.
        guard let url = media.artworkURL, let data = try? await SiteIconStore.download(url),
              let image = UIImage(data: data)
        else { return nil }
        return media.artwork == .logo ? SiteIconTile.make(from: image) ?? fitted(image) : fitted(image)
    }

    /// No bigger than a tile; CarPlay scales it to the row.
    nonisolated static func fitted(_ image: UIImage) -> UIImage {
        let scale = SiteIconTile.side / max(image.size.width, image.size.height, 1)
        guard scale < 1 else { return image }
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
