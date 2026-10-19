import ReplayKit

/// Roadivo's Screen Broadcast (DECISIONS 124): while iOS records the screen, each frame is shrunk to a JPEG and
/// served on the local network, where the car screen's web browser shows it. Nothing is saved or sent elsewhere.
/// Unchecked Sendable: ReplayKit calls `processSampleBuffer` on one queue, the only place `lastFrame` changes.
final class SampleHandler: RPBroadcastSampleHandler, @unchecked Sendable {
    private let server = FrameServer(port: BroadcastHTTP.port, code: BroadcastHTTP.code)
    private let encoder = FrameEncoder(maxDimension: 1280)
    /// About 15 frames a second while a browser waits for one: smooth for video, light on memory and the car's Wi-Fi.
    private let frameInterval: TimeInterval = 1.0 / 15
    /// Otherwise one a second, so a browser that joins on a still screen gets a current picture, not black.
    private let keepFreshInterval: TimeInterval = 1
    private var lastFrame = Date.distantPast

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        server.start { [weak self] in
            // iOS shows this as the broadcast ends. The extension has no in-app language, so it follows the system's.
            let message = String(localized: "Screen Broadcast couldn't start on this network. Try again in a moment.")
            let error = NSError(
                domain: "com.roadivo.broadcast",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
            self?.finishBroadcastWithError(error)
        }
    }

    override func broadcastFinished() {
        server.stop()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        // Only the picture, and only as fast as a browser takes it (busy browsers skip frames anyway).
        guard sampleBufferType == .video else { return }
        let now = Date()
        let interval = server.isViewerReady ? frameInterval : keepFreshInterval
        guard now.timeIntervalSince(lastFrame) >= interval else { return }
        lastFrame = now
        autoreleasepool {
            if let jpeg = encoder.jpeg(from: sampleBuffer) {
                server.send(jpeg)
            }
        }
    }
}
