import CoreImage
import CoreMedia
import ImageIO
import ReplayKit

/// Turns a screen frame into a JPEG small enough to stream: the longer side at most `maxDimension`, turned the way
/// the iPhone is held, at a quality that keeps text readable on a car screen.
final class FrameEncoder {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    private let maxDimension: CGFloat

    init(maxDimension: CGFloat) {
        self.maxDimension = maxDimension
    }

    func jpeg(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        var image = CIImage(cvPixelBuffer: pixels)
        // ReplayKit sends portrait frames and says how the iPhone is turned.
        if let raw = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil)
            as? NSNumber, let orientation = CGImagePropertyOrientation(rawValue: raw.uint32Value) {
            image = image.oriented(orientation)
        }
        let longest = max(image.extent.width, image.extent.height)
        if longest > maxDimension {
            let scale = maxDimension / longest
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        let quality = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        return context.jpegRepresentation(of: image, colorSpace: colorSpace, options: [quality: 0.6])
    }
}
