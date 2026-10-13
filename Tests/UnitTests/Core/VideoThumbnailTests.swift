import AVFoundation
import Foundation
import Testing
@testable import Roadivo

@Suite("Video thumbnails")
struct VideoThumbnailTests {
    /// Writes a 1-second, 160×90 solid-orange H.264 movie.
    private func makeMovie() async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "thumb-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 160, AVVideoHeightKey: 90
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 160, kCVPixelBufferHeightKey as String: 90
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, 160, 90, kCVPixelFormatType_32BGRA, nil, &buffer)
            let pixels = try #require(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            let base = try #require(CVPixelBufferGetBaseAddress(pixels)).assumingMemoryBound(to: UInt8.self)
            for index in stride(from: 0, to: CVPixelBufferGetDataSize(pixels), by: 4) {
                base[index] = 0x20
                base[index + 1] = 0x90
                base[index + 2] = 0xFF
                base[index + 3] = 0xFF
            }
            CVPixelBufferUnlockBaseAddress(pixels, [])
            adaptor.append(pixels, withPresentationTime: CMTime(value: Int64(frame), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return url
    }

    @Test("Renders a frame from a local video and caches it on disk")
    func rendersAndCaches() async throws {
        let movie = try await makeMovie()
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
