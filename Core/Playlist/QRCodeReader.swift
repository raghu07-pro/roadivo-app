import CoreImage
import Foundation

/// Reads the first QR code in a still image (a screenshot or photo of a
/// provider's QR code), for the scanner's "pick a photo" option.
enum QRCodeReader {
    static func decode(imageData: Data) -> String? {
        guard let image = CIImage(data: imageData),
              let detector = CIDetector(
                  ofType: CIDetectorTypeQRCode,
                  context: nil,
                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
              ) else { return nil }
        let codes = detector.features(in: image).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
        return codes.first { !$0.isEmpty }
    }
}
