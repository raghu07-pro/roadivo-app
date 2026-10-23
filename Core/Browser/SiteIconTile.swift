import UIKit

/// A site's icon as a solid square for CarPlay, which shows a see-through tile behind every clear pixel (owner,
/// 2026-10-20). The logo is trimmed and its clear part filled with the colour round its edge, like an app icon; an
/// outline logo, or one with holes in it, goes on white instead (DECISIONS 131).
enum SiteIconTile {
    /// In pixels; CarPlay scales the tile to the car's grid.
    static let side: CGFloat = 180

    /// Edge to edge: CarPlay rounds the corners itself, and any clear margin showed as a grey frame round the icon
    /// (owner, 2026-10-23).
    static func carTile(from image: UIImage) -> UIImage {
        carArtwork { _ in
            (make(from: image) ?? image).draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
    }

    static func carPlaceholder(for name: String) -> UIImage {
        carArtwork { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let letter = String(name.prefix(1)).uppercased() as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .semibold), .foregroundColor: UIColor.white
            ]
            let size = letter.size(withAttributes: attributes)
            letter.draw(
                at: CGPoint(x: (side - size.width) / 2, y: (side - size.height) / 2),
                withAttributes: attributes
            )
        }
    }

    private static func carArtwork(_ draw: (UIGraphicsImageRendererContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
            .image(actions: draw).withRenderingMode(.alwaysOriginal)
    }

    static func make(from image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage, let logo = Logo(cgImage) else { return nil }
        return render { context in
            logo.fill.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let box = side * (logo.fillsTile ? 1 : 0.68)
            let ratio = min(box / CGFloat(logo.trimmed.width), box / CGFloat(logo.trimmed.height))
            let width = CGFloat(logo.trimmed.width) * ratio
            let height = CGFloat(logo.trimmed.height) * ratio
            context.cgContext.interpolationQuality = .high
            UIImage(cgImage: logo.trimmed)
                .draw(in: CGRect(x: (side - width) / 2, y: (side - height) / 2, width: width, height: height))
        }
    }

    /// Until a site's icon arrives: a globe on grey.
    static func placeholder() -> UIImage {
        render { context in
            UIColor.systemGray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let configuration = UIImage.SymbolConfiguration(pointSize: side * 0.5)
            if let globe = UIImage(systemName: "globe", withConfiguration: configuration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                globe.draw(at: CGPoint(x: (side - globe.size.width) / 2, y: (side - globe.size.height) / 2))
            }
        }
    }

    private static func render(_ draw: (UIGraphicsImageRendererContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image(actions: draw)
    }
}

/// How to tile a logo, read from its pixels.
private struct Logo {
    let trimmed: CGImage
    let fill: UIColor
    /// A solid logo fills the tile edge to edge; any other sits on white with a margin.
    let fillsTile: Bool

    init?(_ image: CGImage) {
        guard let pixels = Pixels(image), let box = pixels.solidBox(), let trimmed = image.cropping(to: box.rect) else {
            return nil
        }
        self.trimmed = trimmed
        let outline = pixels.outline(in: box)
        let mean = RGB.mean(of: outline)
        let spread = outline.reduce(0) { $0 + $1.distance(to: mean) } / Double(max(outline.count, 1))
        let area = Double(box.width * box.height)
        let coverage = Double(pixels.solidCount(in: box)) / area
        let holes = Double(pixels.holeCount(in: box)) / area
        // Nearly square and solid, or one colour round the edge with no holes: fill with that colour.
        fillsTile = coverage >= 0.95 || (coverage >= 0.7 && spread < 28 && holes < 0.01)
        fill = fillsTile ? mean.color : .white
    }
}

private struct RGB {
    var red: Double
    var green: Double
    var blue: Double

    var color: UIColor {
        UIColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
    }

    static func mean(of colors: [RGB]) -> RGB {
        let count = Double(max(colors.count, 1))
        return RGB(
            red: colors.reduce(0) { $0 + $1.red } / count,
            green: colors.reduce(0) { $0 + $1.green } / count,
            blue: colors.reduce(0) { $0 + $1.blue } / count
        )
    }

    func distance(to other: RGB) -> Double {
        max(abs(red - other.red), abs(green - other.green), abs(blue - other.blue))
    }
}

/// The smallest box round a logo's solid pixels.
private struct Box {
    let minCol: Int
    let minRow: Int
    let maxCol: Int
    let maxRow: Int

    var width: Int {
        maxCol - minCol + 1
    }

    var height: Int {
        maxRow - minRow + 1
    }

    var rect: CGRect {
        CGRect(x: minCol, y: minRow, width: width, height: height)
    }

    func isOnEdge(_ col: Int, _ row: Int) -> Bool {
        col == minCol || col == maxCol || row == minRow || row == maxRow
    }
}

/// An image's RGBA bytes; rows run top-down, as in `CGImage.cropping(to:)`.
private struct Pixels {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    /// At or below this alpha a pixel counts as clear.
    private static let clear: UInt8 = 16

    init?(_ image: CGImage) {
        width = image.width
        height = image.height
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let isDrawn = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard isDrawn else { return nil }
        self.bytes = bytes
    }

    /// Outside the image counts as clear.
    func isSolid(_ col: Int, _ row: Int) -> Bool {
        guard col >= 0, row >= 0, col < width, row < height else { return false }
        return bytes[(row * width + col) * 4 + 3] > Self.clear
    }

    func solidBox() -> Box? {
        var minCol = width, minRow = height, maxCol = -1, maxRow = -1
        for row in 0..<height {
            for col in 0..<width where isSolid(col, row) {
                minCol = min(minCol, col)
                maxCol = max(maxCol, col)
                minRow = min(minRow, row)
                maxRow = max(maxRow, row)
            }
        }
        return maxCol >= minCol ? Box(minCol: minCol, minRow: minRow, maxCol: maxCol, maxRow: maxRow) : nil
    }

    func solidCount(in box: Box) -> Int {
        (box.minRow...box.maxRow).reduce(0) { total, row in
            total + (box.minCol...box.maxCol).filter { isSolid($0, row) }.count
        }
    }

    /// The colours along the logo's outline: opaque pixels beside clear ones or on the box's edge.
    func outline(in box: Box) -> [RGB] {
        var colors: [RGB] = []
        for row in box.minRow...box.maxRow {
            for col in box.minCol...box.maxCol {
                let index = (row * width + col) * 4
                guard bytes[index + 3] > 200 else { continue }
                let touchesClear = [(col - 1, row), (col + 1, row), (col, row - 1), (col, row + 1)]
                    .contains { !isSolid($0.0, $0.1) }
                if box.isOnEdge(col, row) || touchesClear {
                    colors.append(RGB(
                        red: Double(bytes[index]),
                        green: Double(bytes[index + 1]),
                        blue: Double(bytes[index + 2])
                    ))
                }
            }
        }
        return colors
    }

    /// Clear pixels in the box that the outside can't reach.
    func holeCount(in box: Box) -> Int {
        var reached = [Bool](repeating: false, count: box.width * box.height)
        var pending = (0..<box.width).flatMap { [($0, 0), ($0, box.height - 1)] }
            + (0..<box.height).flatMap { [(0, $0), (box.width - 1, $0)] }
        while let (col, row) = pending.popLast() {
            guard col >= 0, row >= 0, col < box.width, row < box.height, !reached[row * box.width + col],
                  !isSolid(box.minCol + col, box.minRow + row) else { continue }
            reached[row * box.width + col] = true
            pending += [(col - 1, row), (col + 1, row), (col, row - 1), (col, row + 1)]
        }
        var holes = 0
        for row in 0..<box.height {
            for col in 0..<box.width where !reached[row * box.width + col] && !isSolid(
                box.minCol + col,
                box.minRow + row
            ) {
                holes += 1
            }
        }
        return holes
    }
}
