// Draws four rebrand concepts (F–I): a name, its own palette and a logo each, plus a comparison sheet.
// Run from app/playcartv-app: swift Docs/LogoOptions/draw-brand-options.swift
import AppKit
import CoreGraphics

let size = 1024.0
let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

func hex(_ value: UInt32, _ alpha: Double = 1) -> CGColor {
    CGColor(
        srgbRed: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255,
        alpha: alpha
    )
}

func canvas(_ width: Double = size, _ height: Double = size) -> CGContext {
    guard let ctx = CGContext(
        data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { fatalError("context") }
    ctx.interpolationQuality = .high
    return ctx
}

func linear(_ ctx: CGContext, _ colors: [CGColor], _ locations: [CGFloat], from: CGPoint, to: CGPoint) {
    guard let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)
    else { return }
    ctx.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func glow(_ ctx: CGContext, center: CGPoint, radius: Double, color: CGColor) {
    guard let gradient = CGGradient(
        colorsSpace: space, colors: [color, color.copy(alpha: 0) ?? color] as CFArray, locations: [0, 1]
    ) else { return }
    ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

func circle(_ center: CGPoint, _ radius: Double) -> CGRect {
    CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
}

func rounded(_ points: [CGPoint], radius: Double) -> CGPath {
    let path = CGMutablePath()
    let last = points[points.count - 1]
    path.move(to: CGPoint(x: (last.x + points[0].x) / 2, y: (last.y + points[0].y) / 2))
    for index in points.indices {
        path.addArc(tangent1End: points[index], tangent2End: points[(index + 1) % points.count], radius: radius)
    }
    path.closeSubpath()
    return path
}

func image(_ ctx: CGContext) -> CGImage {
    guard let image = ctx.makeImage() else { fatalError("image") }
    return image
}

// MARK: F · Milestream (Night Drive): a play button made of speed streaks

func milestream() -> CGImage {
    let ctx = canvas()
    linear(ctx, [hex(0x050A24), hex(0x0E1B4D), hex(0x1A2F7A)], [0, 0.55, 1], from: CGPoint(x: 0, y: size), to: CGPoint(x: size, y: 0))
    glow(ctx, center: CGPoint(x: 700, y: 512), radius: 560, color: hex(0x3EE6FF, 0.28))

    let tipX = 885.0, baseX = 385.0, half = 300.0, rows = 7
    let pitch = half * 2 / Double(rows), thickness = pitch * 0.6
    let tails = [60.0, 170, 30, 240, 100, 190, 40]
    let bars = CGMutablePath()
    for row in 0..<rows {
        let offset = (Double(row) - Double(rows - 1) / 2) * pitch
        let left = baseX - tails[row]
        bars.addRoundedRect(
            in: CGRect(x: left, y: 512 + offset - thickness / 2, width: tipX + 40 - left, height: thickness),
            cornerWidth: thickness / 2,
            cornerHeight: thickness / 2
        )
    }
    ctx.saveGState()
    // Cut the streaks' right ends along the play button's edges, so its outline reads crisply.
    ctx.addPath(rounded([
        CGPoint(x: tipX, y: 512),
        CGPoint(x: baseX, y: 512 - half),
        CGPoint(x: 0, y: 512 - half),
        CGPoint(x: 0, y: 512 + half),
        CGPoint(x: baseX, y: 512 + half)
    ], radius: 10))
    ctx.clip()
    ctx.addPath(bars)
    ctx.clip()
    linear(
        ctx,
        [hex(0x2F6BFF, 0.15), hex(0x2F6BFF), hex(0x3EE6FF), hex(0xE9FDFF)],
        [0, 0.35, 0.75, 1],
        from: CGPoint(x: 90, y: 0),
        to: CGPoint(x: tipX, y: 0)
    )
    ctx.restoreGState()
    return image(ctx)
}

// MARK: G · Roamcast (Coral Daylight): a compass whose needle is a play button

func roamcast() -> CGImage {
    let ctx = canvas()
    linear(ctx, [hex(0xFFE3CC), hex(0xFFF6EA)], [0, 1], from: .zero, to: CGPoint(x: 0, y: size))
    let plum = hex(0x2E1838)
    let center = CGPoint(x: 512, y: 512)

    ctx.setStrokeColor(plum)
    ctx.setLineWidth(46)
    ctx.strokeEllipse(in: circle(center, 340))
    ctx.setFillColor(plum)
    for quarter in 0..<4 {
        let angle = Double(quarter) * Double.pi / 2
        let radial = CGPoint(x: cos(angle), y: sin(angle))
        func tick(_ distance: Double, _ offset: Double) -> CGPoint {
            let pointX: Double = center.x + radial.x * distance - radial.y * offset
            let pointY: Double = center.y + radial.y * distance + radial.x * offset
            return CGPoint(x: pointX, y: pointY)
        }
        ctx.addPath(rounded([tick(300, 13), tick(300, -13), tick(256, -13), tick(256, 13)], radius: 8))
        ctx.fillPath()
    }

    // The needle points north-east: onward. Its head is the play button.
    let diagonal = (2.0).squareRoot() / 2
    func at(_ along: Double, _ across: Double) -> CGPoint {
        let pointX: Double = center.x + diagonal * (along - across)
        let pointY: Double = center.y + diagonal * (along + across)
        return CGPoint(x: pointX, y: pointY)
    }
    ctx.addPath(rounded([at(-200, 0), at(-30, 84), at(-30, -84)], radius: 18))
    ctx.setFillColor(plum)
    ctx.fillPath()
    let head = rounded([at(250, 0), at(-30, 152), at(-30, -152)], radius: 26)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: hex(0x9C2A1E, 0.35))
    ctx.addPath(head)
    ctx.setFillColor(hex(0xFF5A4E))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(head)
    ctx.clip()
    linear(ctx, [hex(0xFF4F4A), hex(0xFF8A3D)], [0, 1], from: at(-30, 0), to: at(250, 0))
    ctx.restoreGState()
    ctx.setFillColor(hex(0xFFF6EA))
    ctx.fillEllipse(in: circle(center, 24))
    return image(ctx)
}

// MARK: H · Backseat TV (Retro '70s): a road-trip TV over racing stripes

func backseat() -> CGImage {
    let ctx = canvas()
    let brown = hex(0x3A2117), cream = hex(0xF6E6C6)
    ctx.setFillColor(brown)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    glow(ctx, center: CGPoint(x: 512, y: 560), radius: 600, color: hex(0x5A3523, 0.9))

    for (index, color) in [hex(0xF2B035), hex(0xE9752B), hex(0xC8432B)].enumerated() {
        let top = 520 - Double(index) * 86
        ctx.beginPath()
        ctx.move(to: CGPoint(x: -20, y: top - 60))
        ctx.addLine(to: CGPoint(x: size + 20, y: top + 40))
        ctx.addLine(to: CGPoint(x: size + 20, y: top - 30))
        ctx.addLine(to: CGPoint(x: -20, y: top - 130))
        ctx.closePath()
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    ctx.setStrokeColor(cream)
    ctx.setLineCap(.round)
    ctx.setLineWidth(22)
    for tipX in [400.0, 624] {
        ctx.move(to: CGPoint(x: 512, y: 760))
        ctx.addLine(to: CGPoint(x: tipX, y: 880))
    }
    ctx.strokePath()
    ctx.setFillColor(cream)
    for footX in [330.0, 650] {
        ctx.addPath(CGPath(roundedRect: CGRect(x: footX, y: 286, width: 44, height: 60), cornerWidth: 12, cornerHeight: 12, transform: nil))
        ctx.fillPath()
    }
    let body = CGRect(x: 232, y: 320, width: 560, height: 450)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: hex(0x000000, 0.4))
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: 120, cornerHeight: 120, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()

    let screen = body.insetBy(dx: 46, dy: 46)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: screen, cornerWidth: 84, cornerHeight: 84, transform: nil))
    ctx.clip()
    linear(ctx, [hex(0xE9752B), hex(0xF2B035)], [0, 1], from: CGPoint(x: 0, y: screen.minY), to: CGPoint(x: 0, y: screen.maxY))
    ctx.restoreGState()
    let middle = CGPoint(x: screen.midX + 14, y: screen.midY)
    ctx.addPath(rounded([
        CGPoint(x: middle.x + 110, y: middle.y),
        CGPoint(x: middle.x - 80, y: middle.y + 114),
        CGPoint(x: middle.x - 80, y: middle.y - 114)
    ], radius: 22))
    ctx.setFillColor(brown)
    ctx.fillPath()
    return image(ctx)
}

// MARK: I · Lanelight (Synthwave): a striped neon play-sun over a grid road

func lanelight() -> CGImage {
    let ctx = canvas()
    let horizon = size * 0.34
    let magenta = hex(0xFF3D9A)
    linear(ctx, [hex(0x5B1470), hex(0x2A0F45), hex(0x0E0820)], [0, 0.45, 1], from: CGPoint(x: 0, y: horizon), to: CGPoint(x: 0, y: size))
    ctx.setFillColor(hex(0x0B0418))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: horizon))
    ctx.setFillColor(hex(0xFFFFFF, 0.7))
    for (starX, starY, radius) in [(140.0, 900.0, 4.0), (260, 800, 3), (860, 920, 4), (930, 760, 3), (90, 690, 3), (780, 860, 2.5)] {
        ctx.fillEllipse(in: circle(CGPoint(x: starX, y: starY), radius))
    }
    glow(ctx, center: CGPoint(x: 512, y: horizon), radius: 520, color: hex(0xFF3D9A, 0.4))

    let sun = rounded([CGPoint(x: 790, y: horizon + 270), CGPoint(x: 380, y: horizon + 510), CGPoint(x: 380, y: horizon + 30)], radius: 34)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 60, color: hex(0xFF3D9A, 0.9))
    ctx.addPath(sun)
    ctx.setFillColor(hex(0xFF5C8A))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(sun)
    ctx.clip()
    linear(ctx, [hex(0xFF3D9A), hex(0xFF8A3D), hex(0xFFD36E)], [0, 0.5, 1], from: CGPoint(x: 0, y: horizon + 30), to: CGPoint(x: 0, y: horizon + 510))
    // The synthwave sun's cuts, thicker toward the bottom.
    ctx.setFillColor(hex(0x2A0F45))
    for band in 0..<5 {
        let height = 26 - Double(band) * 4.5
        ctx.fill(CGRect(x: 0, y: horizon + 60 + Double(band) * 46, width: size, height: height))
    }
    ctx.restoreGState()

    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: 0, width: size, height: horizon))
    ctx.setShadow(offset: .zero, blur: 14, color: magenta)
    ctx.setStrokeColor(magenta)
    ctx.setLineWidth(5)
    for lane in -7...7 {
        ctx.move(to: CGPoint(x: 512, y: horizon))
        ctx.addLine(to: CGPoint(x: 512 + Double(lane) * 190, y: -20))
    }
    ctx.strokePath()
    for row in 1...7 {
        let depth = Double(row) / 7
        ctx.setLineWidth(2 + 5 * depth)
        let lineY = horizon * (1 - pow(depth, 1.8))
        ctx.move(to: CGPoint(x: 0, y: lineY))
        ctx.addLine(to: CGPoint(x: size, y: lineY))
        ctx.strokePath()
    }
    ctx.restoreGState()
    ctx.setShadow(offset: .zero, blur: 18, color: magenta)
    ctx.setFillColor(hex(0xFFB3D6))
    ctx.fill(CGRect(x: 0, y: horizon - 3, width: size, height: 6))
    return image(ctx)
}

// MARK: Output

func write(_ image: CGImage, to path: String) throws {
    guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { fatalError("png") }
    try data.write(to: URL(fileURLWithPath: path))
}

func text(_ ctx: CGContext, _ string: String, at point: CGPoint, font: NSFont, color: NSColor) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color]).draw(at: point)
    NSGraphicsContext.restoreGraphicsState()
}

func masked(_ ctx: CGContext, _ image: CGImage, _ rect: CGRect) {
    ctx.saveGState()
    let corner = rect.width * 0.2237
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
    ctx.clip()
    ctx.draw(image, in: rect)
    ctx.restoreGState()
}

struct Concept {
    let file, name, idea, theme: String
    let palette: [UInt32]
    let image: CGImage
}

let folder = "Docs/LogoOptions"
let concepts = [
    Concept(file: "F-milestream.png", name: "F · Milestream", idea: "Miles + stream: live TV for every mile",
            theme: "Night Drive", palette: [0x050A24, 0x1A2F7A, 0x2F6BFF, 0x3EE6FF, 0xE9FDFF], image: milestream()),
    Concept(file: "G-roamcast.png", name: "G · Roamcast", idea: "Roam + cast: watch and cast anywhere",
            theme: "Coral Daylight", palette: [0xFFF6EA, 0xFF8A3D, 0xFF5A4E, 0x9C2A1E, 0x2E1838], image: roamcast()),
    Concept(file: "H-backseat-tv.png", name: "H · Backseat TV", idea: "Made for passengers on the road trip",
            theme: "Retro '70s", palette: [0xF6E6C6, 0xF2B035, 0xE9752B, 0xC8432B, 0x3A2117], image: backseat()),
    Concept(file: "I-lanelight.png", name: "I · Lanelight", idea: "Lane + light: the screen that lights the drive",
            theme: "Synthwave", palette: [0x0E0820, 0x5B1470, 0xFF3D9A, 0xFF8A3D, 0xFFD36E], image: lanelight())
]
for concept in concepts {
    try write(concept.image, to: "\(folder)/\(concept.file)")
}

let sheetWidth = 2100.0, sheetHeight = 940.0
let sheet = canvas(sheetWidth, sheetHeight)
sheet.setFillColor(hex(0x121214))
sheet.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight))
let titleFont = NSFont.systemFont(ofSize: 42, weight: .heavy)
let noteFont = NSFont.systemFont(ofSize: 24, weight: .medium)
for (index, concept) in concepts.enumerated() {
    let left = 90 + Double(index) * 500
    masked(sheet, concept.image, CGRect(x: left, y: sheetHeight - 80 - 420, width: 420, height: 420))
    text(sheet, concept.name, at: CGPoint(x: left, y: sheetHeight - 580), font: titleFont, color: .white)
    text(sheet, concept.idea, at: CGPoint(x: left, y: sheetHeight - 622), font: noteFont, color: NSColor(white: 0.65, alpha: 1))
    text(sheet, "Theme: \(concept.theme)", at: CGPoint(x: left, y: sheetHeight - 660), font: noteFont, color: NSColor(white: 0.65, alpha: 1))
    for (swatch, color) in concept.palette.enumerated() {
        let dot = CGRect(x: left + Double(swatch) * 52, y: sheetHeight - 728, width: 40, height: 40)
        sheet.setFillColor(hex(color))
        sheet.fillEllipse(in: dot)
        sheet.setStrokeColor(hex(0xFFFFFF, 0.25))
        sheet.setLineWidth(2)
        sheet.strokeEllipse(in: dot)
    }
    masked(sheet, concept.image, CGRect(x: left, y: sheetHeight - 880, width: 120, height: 120))
    masked(sheet, concept.image, CGRect(x: left + 150, y: sheetHeight - 880, width: 60, height: 60))
}
try write(image(sheet), to: "\(folder)/compare-3.png")
print("Wrote F–I and compare-3.png to \(folder)")
