import AVFoundation
import Foundation
import Testing
@testable import Roadivo

@Suite("Video thumbnails")
struct VideoThumbnailTests {
    @Test("Renders a frame from a local video and caches it on disk")
    func rendersAndCaches() async throws {
        let movie = try await makeTestMovie(seconds: 1)
        let cache = FileManager.default.temporaryDirectory.appending(path: "thumbs-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: movie)
            try? FileManager.default.removeItem(at: cache)
        }
        let thumbnails = VideoThumbnails(directory: cache)

        let image = try #require(await thumbnails.image(for: movie))
        #expect(image.size.width > 0)
        #expect(FileManager.default.fileExists(atPath: cache.appending(path: movie.lastPathComponent + ".jpg").path()))
    }

    @Test("A file that isn't a video gives no thumbnail, not a crash")
    func notAVideo() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "bad-\(UUID().uuidString).mov")
        try Data("nope".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(await VideoThumbnails(directory: FileManager.default.temporaryDirectory).image(for: file) == nil)
    }
}
