import AVFoundation
import UIKit

/// Poster frames for videos on this iPhone, taken a tenth of the way in (past black intros) and
/// cached in memory and on disk, so each video is decoded once.
actor VideoThumbnails {
    static let shared = VideoThumbnails()

    private let memory = PosterMemory()
    private let directory: URL
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    init(directory: URL = URL.cachesDirectory.appending(path: "Thumbnails", directoryHint: .isDirectory)) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// The poster if it's already in memory, so a tile draws it on its first frame instead of
    /// flashing the placeholder.
    nonisolated func cachedImage(for video: URL) -> UIImage? {
        memory.cache.object(forKey: video as NSURL)
    }

    func image(for video: URL) async -> UIImage? {
        if let cached = memory.cache.object(forKey: video as NSURL) {
            return cached
        }
        if let running = inFlight[video] {
            return await running.value
        }
        let file = directory.appending(path: video.lastPathComponent + ".jpg")
        let task = Task<UIImage?, Never> {
            if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
                return image
            }
            guard let image = await Self.render(video) else { return nil }
            // A missing cache file only costs a re-render next time.
            try? image.jpegData(compressionQuality: 0.8)?.write(to: file, options: .atomic)
            return image
        }
        inFlight[video] = task
        let image = await task.value
        inFlight[video] = nil
        if let image {
            memory.cache.setObject(image, forKey: video as NSURL)
        }
        return image
    }

    private static func render(_ video: URL) async -> UIImage? {
        let asset = AVURLAsset(url: video)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        let duration = await (try? asset.load(.duration).seconds) ?? 0
        let second = duration.isFinite && duration > 0 ? min(duration * 0.1, 10) : 0
        guard let frame = try? await generator.image(at: CMTime(seconds: second, preferredTimescale: 600)).image
        else { return nil }
        return UIImage(cgImage: frame)
    }
}

/// The in-memory posters. NSCache is thread-safe, so the actor and the
/// synchronous `cachedImage(for:)` peek can share it.
private final class PosterMemory: @unchecked Sendable {
    let cache = NSCache<NSURL, UIImage>()
}
