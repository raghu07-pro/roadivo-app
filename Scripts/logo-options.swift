// Logo exploration: the current logo (A) and the same scene with a car
// driving toward the play-sun (B), plus a side-by-side sheet with both as
// rounded icons. Output: Docs/LogoOptions/. Run from apps/Roadivo:
//   swift Scripts/logo-options.swift
// Does not touch the app icon.
import AppKit
import CoreGraphics

let size = 1024.0
let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

func rgb(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) -> CGColor {
    CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

let amber = rgb(1.00, 0.714, 0.153)
let asphaltMark = rgb(0.09, 0.098, 0.114)

func ridge(_ ctx: CGContext, horizon: Double, height: Double, seed: Double, color: CGColor) {
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 0, y: horizon))
    for step in 0...64 {
        let pointX = size * Double(step) / 64
        let angle = Double(step) / 64 * .pi * 2
        let wave = sin(angle * (1.3 + seed * 0.4) + seed) * 0.55 + sin(angle * (3.1 + seed) + seed * 2) * 0.3
        ctx.addLine(to: CGPoint(x: pointX, y: horizon + height * (0.55 + wave * 0.45)))
    }
    ctx.addLine(to: CGPoint(x: size, y: horizon))
    ctx.closePath()
    ctx.setFillColor(color)
    ctx.fillPath()
}

func glow(_ ctx: CGContext, center: CGPoint, radius: Double, color: CGColor) {
    guard let gradient = CGGradient(
        colorsSpace: space,
        colors: [color, color.copy(alpha: 0) ?? color] as CFArray,
        locations: [0, 1]
    ) else { return }
    ctx.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: []
    )
}

/// A sedan seen from behind, centred at `center` (its bottom edge), `width` wide.
func car(_ ctx: CGContext, center: CGPoint, width: Double) {
    let height = width * 0.62
    let base = center.y
    let left = center.x - width / 2

    // Road shadow and headlight-free rear glow on the asphalt.
    ctx.setFillColor(rgb(0, 0, 0, 0.45))
    ctx.fillEllipse(in: CGRect(
        x: left - width * 0.04,
        y: base - width * 0.07,
        width: width * 1.08,
        height: width * 0.14
    ))
    glow(
        ctx,
        center: CGPoint(x: center.x, y: base - width * 0.02),
        radius: width * 0.55,
        color: rgb(1, 0.15, 0.1, 0.35)
    )

    // Tyres.
    ctx.setFillColor(rgb(0.03, 0.03, 0.04))
    for side in [-1.0, 1.0] {
        let tyreX = center.x + side * width * 0.36 - width * 0.08
        ctx.fill(CGRect(x: tyreX, y: base, width: width * 0.16, height: height * 0.22))
    }

    // Lower body: a wide rounded slab.
    let body = CGRect(x: left, y: base + height * 0.08, width: width, height: height * 0.46)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: width * 0.09, cornerHeight: width * 0.09, transform: nil)
    ctx.addPath(bodyPath)
    ctx.setFillColor(rgb(0.13, 0.15, 0.24))
    ctx.fillPath()

    // Cabin: a trapezoid with a rounded roof.
    let cabin = CGMutablePath()
    cabin.move(to: CGPoint(x: left + width * 0.12, y: body.maxY - height * 0.02))
    cabin.addLine(to: CGPoint(x: left + width * 0.24, y: body.maxY + height * 0.36))
    cabin.addQuadCurve(
        to: CGPoint(x: left + width * 0.76, y: body.maxY + height * 0.36),
        control: CGPoint(x: center.x, y: body.maxY + height * 0.44)
    )
    cabin.addLine(to: CGPoint(x: left + width * 0.88, y: body.maxY - height * 0.02))
    cabin.closeSubpath()
    ctx.addPath(cabin)
    ctx.setFillColor(rgb(0.10, 0.12, 0.20))
    ctx.fillPath()

    // Rear window catching the sunset.
    let window = CGMutablePath()
    window.move(to: CGPoint(x: left + width * 0.19, y: body.maxY + height * 0.03))
    window.addLine(to: CGPoint(x: left + width * 0.27, y: body.maxY + height * 0.31))
    window.addQuadCurve(
        to: CGPoint(x: left + width * 0.73, y: body.maxY + height * 0.31),
        control: CGPoint(x: center.x, y: body.maxY + height * 0.37)
    )
    window.addLine(to: CGPoint(x: left + width * 0.81, y: body.maxY + height * 0.03))
    window.closeSubpath()
    ctx.saveGState()
    ctx.addPath(window)
    ctx.clip()
    if let sheen = CGGradient(
        colorsSpace: space,
        colors: [rgb(0.98, 0.55, 0.30, 0.9), rgb(0.30, 0.20, 0.38, 0.95)] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawLinearGradient(
            sheen,
            start: CGPoint(x: center.x, y: body.maxY + height * 0.33),
            end: CGPoint(x: center.x, y: body.maxY),
            options: []
        )
    }
    ctx.restoreGState()

    // Tail-light bar across the boot, glowing red.
    let lightY = body.minY + body.height * 0.62
    for side in [-1.0, 1.0] {
        let lamp = CGRect(
            x: side < 0 ? left + width * 0.04 : left + width * 0.71,
            y: lightY,
            width: width * 0.25,
            height: height * 0.075
        )
        glow(ctx, center: CGPoint(x: lamp.midX, y: lamp.midY), radius: width * 0.2, color: rgb(1, 0.1, 0.08, 0.55))
        ctx.addPath(CGPath(
            roundedRect: lamp,
            cornerWidth: lamp.height / 2,
            cornerHeight: lamp.height / 2,
            transform: nil
        ))
        ctx.setFillColor(rgb(1, 0.18, 0.16))
        ctx.fillPath()
    }
    ctx.setFillColor(rgb(1, 0.18, 0.16, 0.85))
    ctx.fill(CGRect(x: left + width * 0.29, y: lightY + height * 0.025, width: width * 0.42, height: height * 0.02))

    // Number plate in sun amber.
    let plate = CGRect(
        x: center.x - width * 0.11,
        y: body.minY + body.height * 0.18,
        width: width * 0.22,
        height: height * 0.1
    )
    ctx.addPath(CGPath(roundedRect: plate, cornerWidth: 6, cornerHeight: 6, transform: nil))
    ctx.setFillColor(amber)
    ctx.fillPath()
}

/// The logo scene. CoreGraphics' y axis points up.
func logo(withCar: Bool) -> CGImage {
    guard let ctx = CGContext(
        data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { fatalError("context") }
    let horizon = size * 0.40

    let skyColors = [rgb(1.00, 0.74, 0.38), rgb(0.93, 0.42, 0.30), rgb(0.40, 0.20, 0.45), rgb(0.12, 0.14, 0.38)]
    if let sky = CGGradient(colorsSpace: space, colors: skyColors as CFArray, locations: [0, 0.3, 0.7, 1]) {
        ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: horizon), end: CGPoint(x: 0, y: size), options: [])
    }

    if withCar {
        // Thin sunset clouds.
        ctx.setFillColor(rgb(1.0, 0.55, 0.35, 0.55))
        for (cloudX, cloudY, cloudW) in [
            (70.0, 760.0, 260.0),
            (700.0, 800.0, 250.0),
            (40.0, 690.0, 170.0),
            (780.0, 720.0, 200.0)
        ] {
            let cloud = CGRect(x: cloudX, y: cloudY, width: cloudW, height: 22)
            ctx.addPath(CGPath(roundedRect: cloud, cornerWidth: 11, cornerHeight: 11, transform: nil))
            ctx.fillPath()
        }
    }

    // The play-sun.
    let radius = size * 0.2
    let sun = CGRect(x: size / 2 - radius, y: horizon + radius * 0.05, width: radius * 2, height: radius * 2)
    glow(ctx, center: CGPoint(x: sun.midX, y: sun.midY), radius: radius * 1.6, color: rgb(1.0, 0.75, 0.3, 0.45))
    ridge(ctx, horizon: horizon, height: size * 0.15, seed: 1, color: rgb(0.42, 0.23, 0.36))
    ctx.setFillColor(amber)
    ctx.fillEllipse(in: sun)
    let side = radius * 0.95
    let mid = CGPoint(x: sun.midX + side * 0.1, y: sun.midY)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: mid.x + side * 0.55, y: mid.y))
    ctx.addLine(to: CGPoint(x: mid.x - side * 0.45, y: mid.y + side * 0.58))
    ctx.addLine(to: CGPoint(x: mid.x - side * 0.45, y: mid.y - side * 0.58))
    ctx.closePath()
    ctx.setFillColor(asphaltMark)
    ctx.fillPath()
    ridge(ctx, horizon: horizon, height: size * 0.06, seed: 2, color: rgb(0.24, 0.15, 0.25))

    // Ground and road.
    ctx.setFillColor(rgb(0.16, 0.13, 0.16))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: horizon))
    if withCar {
        // The sun's reflection on the road ahead.
        glow(ctx, center: CGPoint(x: size / 2, y: horizon), radius: size * 0.35, color: rgb(1.0, 0.6, 0.25, 0.35))
    }
    ctx.beginPath()
    ctx.move(to: CGPoint(x: size * 0.48, y: horizon))
    ctx.addLine(to: CGPoint(x: size * 0.52, y: horizon))
    ctx.addLine(to: CGPoint(x: size * 0.98, y: 0))
    ctx.addLine(to: CGPoint(x: size * 0.02, y: 0))
    ctx.closePath()
    ctx.setFillColor(rgb(0.11, 0.11, 0.13, withCar ? 0.92 : 1))
    ctx.fillPath()

    ctx.setStrokeColor(rgb(1, 1, 1, 0.55))
    ctx.setLineWidth(10)
    for edge in [-1.0, 1.0] {
        ctx.move(to: CGPoint(x: size / 2 + edge * size * 0.02, y: horizon))
        ctx.addLine(to: CGPoint(x: size / 2 + edge * size * 0.44, y: 0))
    }
    ctx.strokePath()

    ctx.setFillColor(amber)
    for index in 0..<8 {
        let far = pow(Double(index) / 8, 2.0)
        let near = pow((Double(index) + 0.5) / 8, 2.0)
        let top = horizon - horizon * far
        let bottom = horizon - horizon * near
        let width = max(4, size * 0.05 * near)
        ctx.fill(CGRect(x: size / 2 - width / 2, y: bottom, width: width, height: top - bottom))
    }

    if withCar {
        car(ctx, center: CGPoint(x: size / 2, y: horizon - size * 0.21), width: size * 0.36)
    }

    guard let image = ctx.makeImage() else { fatalError("image") }
    return image
}

func write(_ image: CGImage, to path: String) throws {
    guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { fatalError("png") }
    try data.write(to: URL(fileURLWithPath: path))
}

let current = logo(withCar: false)
let withCar = logo(withCar: true)
try write(current, to: "Docs/LogoOptions/A-current.png")
try write(withCar, to: "Docs/LogoOptions/B-with-car.png")

/// Side-by-side sheet: both as iOS-style rounded icons on asphalt, with labels.
let sheetW = 1500.0, sheetH = 860.0
guard let sheet = CGContext(
    data: nil, width: Int(sheetW), height: Int(sheetH), bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("sheet") }
sheet.setFillColor(rgb(0.07, 0.078, 0.09))
sheet.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
for (index, image) in [current, withCar].enumerated() {
    let rect = CGRect(x: 120 + Double(index) * 700, y: 200, width: 560, height: 560)
    sheet.saveGState()
    sheet.addPath(CGPath(roundedRect: rect, cornerWidth: 126, cornerHeight: 126, transform: nil))
    sheet.clip()
    sheet.draw(image, in: rect)
    sheet.restoreGState()
    // Small home-screen size, to judge legibility.
    let small = CGRect(x: rect.maxX - 120, y: 40, width: 120, height: 120)
    sheet.saveGState()
    sheet.addPath(CGPath(roundedRect: small, cornerWidth: 27, cornerHeight: 27, transform: nil))
    sheet.clip()
    sheet.draw(image, in: small)
    sheet.restoreGState()
    let label = index == 0 ? "A · Current" : "B · With car"
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 44, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: sheet, flipped: false)
    NSAttributedString(string: label, attributes: attributes).draw(at: CGPoint(x: rect.minX, y: 80))
    NSGraphicsContext.restoreGraphicsState()
}

guard let sheetImage = sheet.makeImage() else { fatalError("sheet image") }
try write(sheetImage, to: "Docs/LogoOptions/compare.png")
