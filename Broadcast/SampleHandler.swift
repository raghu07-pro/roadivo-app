import ReplayKit

/// Roadivo's Screen Broadcast (DECISIONS 124): while iOS records the screen, each frame is shrunk to a JPEG and
/// served on the local network, where the car screen's web browser shows it. Nothing is saved or sent elsewhere.
final class SampleHandler: RPBroadcastSampleHandler {
    private let server = FrameServer(port: BroadcastHTTP.port)
    private let encoder = FrameEncoder(maxDimension: 1280)
    /// About 15 frames a second: smooth for video, light enough for the extension's memory and the car's Wi-Fi.
    private let frameInterval: TimeInterval = 1.0 / 15
    private var lastFrame = Date.distantPast

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        server.start()
    }

    override func broadcastFinished() {
        server.stop()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        // Only the picture; with nobody watching, frames aren't even encoded.
        guard sampleBufferType == .video, server.hasViewers else { return }
        let now = Date()
        guard now.timeIntervalSince(lastFrame) >= frameInterval else { return }
        lastFrame = now
        autoreleasepool {
            if let jpeg = encoder.jpeg(from: sampleBuffer) {
                server.send(jpeg)
            }
        }
    }
}
