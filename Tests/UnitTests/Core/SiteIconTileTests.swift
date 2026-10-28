import Testing
import UIKit
@testable import PlayCarTV

@Suite("CarPlay site tiles")
struct SiteIconTileTests {
    /// A 100 × 100 icon, clear except for what `draw` paints.
    private func icon(_ draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100), format: format)
            .image { draw($0.cgContext) }
    }

    /// The tile's colour at a pixel, as 0–255 red, green and blue.
    private func color(of image: UIImage, col: Int, row: Int) throws -> [Int] {
        let cgImage = try #require(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &bytes,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        // Shifts the image so the wanted pixel lands on the one-pixel canvas; rows count from the top.
        context.draw(cgImage, in: CGRect(
            x: -col,
            y: row - cgImage.height + 1,
            width: cgImage.width,
            height: cgImage.height
        ))
        return [Int(bytes[0]), Int(bytes[1]), Int(bytes[2]), Int(bytes[3])]
    }

    @Test("A solid logo with clear margins becomes a square of its own colour, edge to edge")
    func solidLogo() throws {
        let logo = icon { context in
            context.setFillColor(UIColor.red.cgColor)
            context.fill(CGRect(x: 20, y: 30, width: 60, height: 40))
        }

        let tile = try #require(SiteIconTile.make(from: logo))

        #expect(tile.size == CGSize(width: SiteIconTile.side, height: SiteIconTile.side))
        let corner = try color(of: tile, col: 2, row: 2)
        #expect(corner[0] > 220 && corner[1] < 40 && corner[2] < 40)
        #expect(corner[3] == 255)
    }

    @Test("An outline logo, with a hole in it, sits on white so its shape still shows")
    func outlineLogo() throws {
        let ring = icon { context in
            context.setStrokeColor(UIColor.blue.cgColor)
            context.setLineWidth(8)
            context.strokeEllipse(in: CGRect(x: 10, y: 10, width: 80, height: 80))
        }

        let tile = try #require(SiteIconTile.make(from: ring))

        #expect(try color(of: tile, col: 2, row: 2).prefix(3).allSatisfy { $0 > 240 })
        let centre = Int(SiteIconTile.side / 2)
        #expect(try color(of: tile, col: centre, row: centre).prefix(3).allSatisfy { $0 > 240 })
    }

    @Test("An icon with nothing in it gives no tile, so the placeholder shows")
    func emptyIcon() {
        #expect(SiteIconTile.make(from: icon { _ in }) == nil)
        #expect(SiteIconTile.placeholder().size == CGSize(width: SiteIconTile.side, height: SiteIconTile.side))
    }

    @Test("Car artwork has transparent rounded corners and an opaque logo centre")
    func roundedCarArtwork() throws {
        let logo = icon { context in
            context.setFillColor(UIColor.red.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        for tile in [SiteIconTile.carTile(from: logo), SiteIconTile.carPlaceholder(for: "Example")] {
            #expect(tile.size == CGSize(width: SiteIconTile.side, height: SiteIconTile.side))
            #expect(tile.renderingMode == .alwaysOriginal)
            #expect(try color(of: tile, col: 1, row: 1)[3] == 0)
            #expect(try color(of: tile, col: 180, row: 180)[3] == 255)
        }
    }
}
