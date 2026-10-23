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
            image = image.oriented(Self.upright(orientation))
        }
        let longest = max(image.extent.width, image.extent.height)
        if longest > maxDimension {
            let scale = maxDimension / longest
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        let quality = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        return context.jpegRepresentation(of: image, colorSpace: colorSpace, options: [quality: 0.6])
    }

    /// ReplayKit's left and right turn the picture the other way from Core Image's: used as given, a landscape
    /// iPhone showed upside down on the car (owner, 2026-10-23). Portrait and upside-down need no swap.
    private static func upright(_ orientation: CGImagePropertyOrientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .left: .right
        case .right: .left
        case .leftMirrored: .rightMirrored
        case .rightMirrored: .leftMirrored
        default: orientation
        }
    }
}
