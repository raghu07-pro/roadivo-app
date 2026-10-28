// Draws three more PlayCarTV logo concepts (C, D, E) and a comparison sheet beside the current icon.
// Run from app/playcartv-app: swift Docs/LogoOptions/draw-logo-options.swift
import AppKit
import CoreGraphics
import CoreText

let size = 1024.0
let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

func rgb(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) -> CGColor {
    CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

// The current icon's light palette (Scripts/generate-app-icon.swift).
let amber = rgb(1.00, 0.714, 0.153)
let mark = rgb(0.09, 0.098, 0.114)
let peach = rgb(1.00, 0.74, 0.38)
let coral = rgb(0.93, 0.42, 0.30)
let purple = rgb(0.40, 0.20, 0.45)
let navy = rgb(0.12, 0.14, 0.38)
let asphalt = rgb(0.11, 0.11, 0.13)
let ground = rgb(0.16, 0.13, 0.16)
let farRidge = rgb(0.42, 0.23, 0.36)
let nearRidge = rgb(0.24, 0.15, 0.25)
let warmGlow = rgb(1.0, 0.75, 0.3, 0.45)
let edge = rgb(1, 1, 1, 0.55)
let wheelDark = rgb(0.10, 0.10, 0.14)

func canvas(_ width: Double = size, _ height: Double = size) -> CGContext {
    guard let ctx = CGContext(
        data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { fatalError("context") }
    ctx.setShouldAntialias(true)
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

func circle(_ center: CGPoint, _ radius: Double) -> CGRect {
    CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
}

/// The icon's play mark, same proportions as the sun's.
func play(_ ctx: CGContext, in sunCenter: CGPoint, radius: Double, color: CGColor) {
    let side = radius * 0.95
    let mid = CGPoint(x: sunCenter.x + side * 0.1, y: sunCenter.y)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: mid.x + side * 0.55, y: mid.y))
    ctx.addLine(to: CGPoint(x: mid.x - side * 0.45, y: mid.y + side * 0.58))
    ctx.addLine(to: CGPoint(x: mid.x - side * 0.45, y: mid.y - side * 0.58))
    ctx.closePath()
    ctx.setFillColor(color)
    ctx.fillPath()
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

// MARK: C · Steering wheel: Car Mode and CarPlay, the hub is the play-sun

func steeringWheel() -> CGImage {
    let ctx = canvas()
    linear(ctx, [peach, coral, purple, navy], [0, 0.3, 0.7, 1], from: .zero, to: CGPoint(x: 0, y: size))
    let center = CGPoint(x: size / 2, y: size * 0.49)
    glow(ctx, center: center, radius: size * 0.55, color: warmGlow)

    let outer = 384.0, inner = 300.0
    ctx.addEllipse(in: circle(CGPoint(x: center.x, y: center.y - 16), outer + 4))
    ctx.addEllipse(in: circle(CGPoint(x: center.x, y: center.y - 16), inner - 4))
    ctx.setFillColor(rgb(0, 0, 0, 0.22))
    ctx.fillPath(using: .evenOdd)

    let wheel = CGMutablePath()
    wheel.addEllipse(in: circle(center, outer))
    wheel.addEllipse(in: circle(center, inner))
    ctx.addPath(wheel)
    ctx.setFillColor(wheelDark)
    ctx.fillPath(using: .evenOdd)

    // Spokes: a wide bar across and one down, as a real wheel's.
    ctx.addPath(rounded([
        CGPoint(x: center.x - inner - 10, y: center.y + 24),
        CGPoint(x: center.x - 140, y: center.y + 54),
        CGPoint(x: center.x + 140, y: center.y + 54),
        CGPoint(x: center.x + inner + 10, y: center.y + 24),
        CGPoint(x: center.x + inner + 10, y: center.y - 56),
        CGPoint(x: center.x + 140, y: center.y - 96),
        CGPoint(x: center.x - 140, y: center.y - 96),
        CGPoint(x: center.x - inner - 10, y: center.y - 56)
    ], radius: 18))
    ctx.addPath(rounded([
        CGPoint(x: center.x - 92, y: center.y - 120),
        CGPoint(x: center.x + 92, y: center.y - 120),
        CGPoint(x: center.x + 58, y: center.y - inner - 10),
        CGPoint(x: center.x - 58, y: center.y - inner - 10)
    ], radius: 14))
    ctx.setFillColor(wheelDark)
    ctx.fillPath()

    // Rim light from the sunset, and the lane-yellow top marker.
    ctx.setStrokeColor(rgb(1, 0.78, 0.45, 0.35))
    ctx.setLineWidth(7)
    ctx.addArc(center: center, radius: outer - 9, startAngle: .pi * 0.58, endAngle: .pi * 0.92, clockwise: false)
    ctx.strokePath()
    ctx.addArc(center: center, radius: outer - 9, startAngle: .pi * 0.08, endAngle: .pi * 0.42, clockwise: false)
    ctx.strokePath()
    let marker = CGRect(x: center.x - 24, y: center.y + inner - 2, width: 48, height: outer - inner + 4)
    ctx.addPath(CGPath(roundedRect: marker, cornerWidth: 10, cornerHeight: 10, transform: nil))
    ctx.setFillColor(amber)
    ctx.fillPath()

    let hub = 172.0
    ctx.setFillColor(wheelDark)
    ctx.fillEllipse(in: circle(center, hub + 22))
    glow(ctx, center: center, radius: hub * 1.25, color: rgb(1, 0.75, 0.3, 0.35))
    ctx.setFillColor(amber)
    ctx.fillEllipse(in: circle(center, hub))
    play(ctx, in: center, radius: hub, color: mark)

    guard let image = ctx.makeImage() else { fatalError("image") }
    return image
}

// MARK: D · Road play: the road to the horizon, turned on its side, is the play button

func roadPlay() -> CGImage {
    let ctx = canvas()
    linear(
        ctx,
        [rgb(0.62, 0.27, 0.40), purple, rgb(0.20, 0.15, 0.40), navy],
        [0, 0.35, 0.7, 1],
        from: .zero,
        to: CGPoint(x: 0, y: size)
    )
    let center = CGPoint(x: size / 2, y: size / 2)
    let radius = 360.0
    glow(ctx, center: center, radius: radius * 1.55, color: warmGlow)
    ctx.setFillColor(amber)
    ctx.fillEllipse(in: circle(center, radius))

    let side = radius * 1.15
    let mid = CGPoint(x: center.x + side * 0.1, y: center.y)
    let tip = CGPoint(x: mid.x + side * 0.55, y: mid.y)
    let baseX = mid.x - side * 0.45
    let half = side * 0.58
    let road = rounded([
        tip,
        CGPoint(x: baseX, y: mid.y - half),
        CGPoint(x: baseX, y: mid.y + half)
    ], radius: 30)
    ctx.addPath(road)
    ctx.setFillColor(asphalt)
    ctx.fillPath()

    ctx.saveGState()
    ctx.addPath(road)
    ctx.clip()
    ctx.setStrokeColor(edge)
    ctx.setLineWidth(10)
    for direction in [-1.0, 1.0] {
        ctx.move(to: CGPoint(x: baseX, y: mid.y + direction * half * 0.80))
        ctx.addLine(to: CGPoint(x: tip.x - 40, y: mid.y + direction * 6))
    }
    ctx.strokePath()
    // The centre line shrinks toward the tip, as the road's dashes do toward the horizon.
    let length = tip.x - baseX
    ctx.setFillColor(amber)
    for index in 1..<7 {
        let far = pow(Double(index) / 7, 2)
        let near = pow((Double(index) + 0.5) / 7, 2)
        let thickness = max(5, 40 * near)
        ctx.fill(CGRect(
            x: tip.x - near * length,
            y: mid.y - thickness / 2,
            width: (near - far) * length,
            height: thickness
        ))
    }
    ctx.restoreGState()

    guard let image = ctx.makeImage() else { fatalError("image") }
    return image
}

// MARK: E · Route pin: Maps' destination pin, whose head is the play-sun, at the end of a winding road

/// The current icon's sedan seen from behind (Scripts/generate-app-icon.swift, light palette); `center.y` is where its
/// tyres meet the road.
func car(_ ctx: CGContext, center: CGPoint, width: Double) {
    let tailLight = rgb(1, 0.18, 0.16)
    let height = width * 0.62
    let base = center.y
    let left = center.x - width / 2

    ctx.setFillColor(rgb(0, 0, 0, 0.45))
    ctx.fillEllipse(in: CGRect(x: left - width * 0.04, y: base - width * 0.07, width: width * 1.08, height: width * 0.14))
    glow(ctx, center: CGPoint(x: center.x, y: base - width * 0.02), radius: width * 0.55, color: rgb(1, 0.18, 0.16, 0.35))
    ctx.setFillColor(rgb(0.03, 0.03, 0.04))
    for side in [-1.0, 1.0] {
        ctx.fill(CGRect(x: center.x + side * width * 0.36 - width * 0.08, y: base, width: width * 0.16, height: height * 0.22))
    }
    let body = CGRect(x: left, y: base + height * 0.08, width: width, height: height * 0.46)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: width * 0.09, cornerHeight: width * 0.09, transform: nil))
    ctx.setFillColor(rgb(0.13, 0.15, 0.24))
    ctx.fillPath()

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
    linear(
        ctx,
        [rgb(0.98, 0.55, 0.30, 0.9), rgb(0.30, 0.20, 0.38, 0.95)],
        [0, 1],
        from: CGPoint(x: center.x, y: body.maxY + height * 0.33),
        to: CGPoint(x: center.x, y: body.maxY)
    )
    ctx.restoreGState()

    let lightY = body.minY + body.height * 0.62
    for side in [-1.0, 1.0] {
        let lamp = CGRect(
            x: side < 0 ? left + width * 0.04 : left + width * 0.71,
            y: lightY,
            width: width * 0.25,
            height: height * 0.075
        )
        glow(ctx, center: CGPoint(x: lamp.midX, y: lamp.midY), radius: width * 0.2, color: rgb(1, 0.18, 0.16, 0.55))
        ctx.addPath(CGPath(roundedRect: lamp, cornerWidth: lamp.height / 2, cornerHeight: lamp.height / 2, transform: nil))
        ctx.setFillColor(tailLight)
        ctx.fillPath()
    }
    ctx.setFillColor(rgb(1, 0.18, 0.16, 0.85))
    ctx.fill(CGRect(x: left + width * 0.29, y: lightY + height * 0.025, width: width * 0.42, height: height * 0.02))
    let plate = CGRect(x: center.x - width * 0.11, y: body.minY + body.height * 0.18, width: width * 0.22, height: height * 0.1)
    ctx.addPath(CGPath(roundedRect: plate, cornerWidth: 6, cornerHeight: 6, transform: nil))
    ctx.setFillColor(amber)
    ctx.fillPath()
}

/// E, and with `withCar` the combined logo J: the current icon's car and clouds on E's road to the pin.
func routePin(withCar: Bool = false) -> CGImage {
    let ctx = canvas()
    let horizon = size * 0.34
    linear(ctx, [peach, coral, purple, navy], [0, 0.3, 0.7, 1], from: CGPoint(x: 0, y: horizon), to: CGPoint(x: 0, y: size))
    if withCar {
        ctx.setFillColor(rgb(1.0, 0.55, 0.35, 0.55))
        for (cloudX, cloudY, cloudW) in [(40.0, 760.0, 250.0), (740.0, 800.0, 250.0), (20.0, 690.0, 160.0), (800.0, 720.0, 190.0)] {
            let cloud = CGRect(x: cloudX, y: cloudY, width: cloudW, height: 22)
            ctx.addPath(CGPath(roundedRect: cloud, cornerWidth: 11, cornerHeight: 11, transform: nil))
            ctx.fillPath()
        }
    }

    let head = CGPoint(x: size / 2, y: size * 0.70)
    let headRadius = 168.0
    glow(ctx, center: head, radius: headRadius * 2.1, color: warmGlow)
    ridge(ctx, horizon: horizon, height: size * 0.14, seed: 1, color: farRidge)
    ridge(ctx, horizon: horizon, height: size * 0.055, seed: 2, color: nearRidge)
    ctx.setFillColor(ground)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: horizon))
    glow(ctx, center: CGPoint(x: size / 2, y: horizon), radius: size * 0.3, color: warmGlow)

    // A winding road laid flat on the ground and seen in perspective, so its edges never fold over.
    let lateral = 260.0, rise = horizon + 40, roadWidth = 0.9
    func roadX(_ depth: Double) -> Double {
        2.4 * sin(0.62 * (depth - 1)) * min(1, (depth - 1) / 2.5) * exp(-max(0, depth - 7) / 4)
    }
    func project(_ across: Double, _ depth: Double) -> CGPoint {
        CGPoint(x: size / 2 + (roadX(depth) + across) * lateral / depth, y: horizon - rise / depth)
    }
    func strip(_ from: Double, _ to: Double, near: Double, far: Double) {
        let steps = 160
        let depths = (0...steps).map { near * pow(far / near, Double($0) / Double(steps)) }
        ctx.beginPath()
        ctx.addLines(between: depths.map { project(from, $0) } + depths.reversed().map { project(to, $0) })
        ctx.closePath()
        ctx.fillPath()
    }
    ctx.setFillColor(asphalt)
    strip(-roadWidth, roadWidth, near: 1, far: 500)
    ctx.setFillColor(edge)
    strip(-roadWidth * 0.90, -roadWidth * 0.84, near: 1, far: 500)
    strip(roadWidth * 0.84, roadWidth * 0.90, near: 1, far: 500)
    ctx.setFillColor(amber)
    var dash = 1.2
    while dash < 80 {
        strip(-0.06, 0.06, near: dash, far: dash + 0.7)
        dash += 1.6
    }

    if withCar {
        // Near the bottom, where the road is still straight, sized to its lane as in the current icon.
        let depth = 1.35
        let laneCentre = project(0, depth)
        car(ctx, center: laneCentre, width: 0.78 * 2 * roadWidth * lateral / depth)
    }

    // The pin stands where the road meets the horizon.
    let tip = CGPoint(x: size / 2, y: horizon + 4)
    ctx.setFillColor(rgb(0, 0, 0, 0.45))
    ctx.fillEllipse(in: CGRect(x: tip.x - 46, y: tip.y - 9, width: 92, height: 18))
    let distance = head.y - tip.y
    let spread = acos(headRadius / distance)
    let pin = CGMutablePath()
    pin.move(to: tip)
    pin.addArc(center: head, radius: headRadius, startAngle: -.pi / 2 + spread, endAngle: .pi * 1.5 - spread, clockwise: false)
    pin.closeSubpath()
    ctx.addPath(pin)
    ctx.setFillColor(amber)
    ctx.fillPath()
    ctx.saveGState()
    ctx.addPath(pin)
    ctx.clip()
    linear(
        ctx,
        [rgb(0.75, 0.42, 0.05, 0.55), rgb(1, 0.714, 0.153, 0)],
        [0, 1],
        from: tip,
        to: CGPoint(x: tip.x, y: head.y - headRadius * 0.2)
    )
    ctx.restoreGState()
    play(ctx, in: head, radius: headRadius * 0.86, color: mark)

    guard let image = ctx.makeImage() else { fatalError("image") }
    return image
}

// MARK: Output

func write(_ image: CGImage, to path: String) throws {
    guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { fatalError("png") }
    try data.write(to: URL(fileURLWithPath: path))
}

func load(_ path: String) -> CGImage {
    guard let image = NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { fatalError("load \(path)") }
    return image
}

for name in ["Overpass-ExtraBold", "Overpass-Bold"] {
    CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: "Resources/Fonts/\(name).ttf") as CFURL, .process, nil)
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

let folder = "Docs/LogoOptions"
let options: [(file: String, title: String, feature: String, image: CGImage)] = [
    ("", "B · Current", "Car driving to the play-sun", load("Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")),
    ("C-steering-wheel.png", "C · Steering Wheel", "Car Mode & CarPlay", steeringWheel()),
    ("D-road-play.png", "D · Road Play", "The road is the play button", roadPlay()),
    ("E-route-pin.png", "E · Route Pin", "Maps: play on the way", routePin())
]
for option in options where !option.file.isEmpty {
    try write(option.image, to: "\(folder)/\(option.file)")
}

let sheetWidth = 2100.0, sheetHeight = 860.0
let sheet = canvas(sheetWidth, sheetHeight)
sheet.setFillColor(rgb(0.07, 0.07, 0.08))
sheet.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight))
let titleFont = NSFont.systemFont(ofSize: 42, weight: .heavy)
let noteFont = NSFont.systemFont(ofSize: 26, weight: .medium)
for (index, option) in options.enumerated() {
    let left = 90 + Double(index) * 500
    masked(sheet, option.image, CGRect(x: left, y: sheetHeight - 90 - 420, width: 420, height: 420))
    text(sheet, option.title, at: CGPoint(x: left, y: sheetHeight - 590), font: titleFont, color: .white)
    text(sheet, option.feature, at: CGPoint(x: left, y: sheetHeight - 636), font: noteFont, color: NSColor(white: 0.62, alpha: 1))
    // Home-screen and Settings sizes.
    masked(sheet, option.image, CGRect(x: left, y: sheetHeight - 800, width: 120, height: 120))
    masked(sheet, option.image, CGRect(x: left + 150, y: sheetHeight - 800, width: 60, height: 60))
}
guard let sheetImage = sheet.makeImage() else { fatalError("sheet") }
try write(sheetImage, to: "\(folder)/compare-2.png")

// J: the current icon and E combined, beside both.
let combined = routePin(withCar: true)
try write(combined, to: "\(folder)/J-route-pin-car.png")
let pair: [(title: String, note: String, image: CGImage)] = [
    (options[0].title, options[0].feature, options[0].image),
    (options[3].title, options[3].feature, options[3].image),
    ("J · Road to the Pin", "The car drives on to the play-pin", combined)
]
let pairWidth = 1600.0
let pairSheet = canvas(pairWidth, sheetHeight)
pairSheet.setFillColor(rgb(0.07, 0.07, 0.08))
pairSheet.fill(CGRect(x: 0, y: 0, width: pairWidth, height: sheetHeight))
for (index, option) in pair.enumerated() {
    let left = 90 + Double(index) * 500
    masked(pairSheet, option.image, CGRect(x: left, y: sheetHeight - 90 - 420, width: 420, height: 420))
    text(pairSheet, option.title, at: CGPoint(x: left, y: sheetHeight - 590), font: titleFont, color: .white)
    text(pairSheet, option.note, at: CGPoint(x: left, y: sheetHeight - 636), font: noteFont, color: NSColor(white: 0.62, alpha: 1))
    masked(pairSheet, option.image, CGRect(x: left, y: sheetHeight - 800, width: 120, height: 120))
    masked(pairSheet, option.image, CGRect(x: left + 150, y: sheetHeight - 800, width: 60, height: 60))
}
guard let pairImage = pairSheet.makeImage() else { fatalError("pair sheet") }
try write(pairImage, to: "\(folder)/compare-4.png")
print("Wrote C, D, E, J, compare-2.png and compare-4.png to \(folder)")
