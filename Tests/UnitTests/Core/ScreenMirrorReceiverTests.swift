import Foundation
import Testing
import UIKit
@testable import PlayCarTV

@Suite("CarPlay window's screen mirror")
@MainActor
struct ScreenMirrorReceiverTests {
    @Test(
        "The car window reads the iPhone's own broadcast over loopback and hears when it ends",
        .timeLimit(.minutes(1))
    )
    func readsLoopbackBroadcast() async throws {
        let jpeg = try #require(UIGraphicsImageRenderer(size: CGSize(width: 8, height: 6), format: Self.format)
            .jpegData(withCompressionQuality: 0.8) { context in
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 8, height: 6))
            })
        let server = try LoopbackBroadcast(answers: [Self.path: BroadcastHTTP.streamHeader + BroadcastHTTP.part(jpeg)])
        let port = await server.start()
        let receiver = ScreenMirrorReceiver(port: port, path: Self.path)
        receiver.decodesFrames = true
        let (heard, report) = AsyncStream.makeStream(of: String.self)
        receiver.start { event in
            report.yield("\(event)")
        } onFrame: { frame in
            report.yield("frame \(Int(frame.size.width))×\(Int(frame.size.height))")
        }
        var events = heard.makeAsyncIterator()
        let opening: Set = await [events.next(), events.next()]
        #expect(opening == ["started", "frame 8×6"])

        server.endBroadcast()
        #expect(await events.next() == "ended")
        receiver.stop()
        server.stop()
    }

    private static let path = "/test/stream"

    private static var format: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return format
    }
}
