// Draws AppIcon (a car on a winding road to the play-pin) and AppIcon-Classic (the empty road to the play-sun, an
// alternate), each light, dark and tinted. Run from the app folder: swift Scripts/generate-app-icon.swift
import AppKit
import CoreGraphics

let size = 1024.0
let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

func rgb(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) -> CGColor {
    CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

enum Variant { case light, dark, tinted }

struct Palette {
    let sky: [CGColor]
    /// The original icon's three-stop sky, kept exactly for AppIcon-Classic.
    let classicSky: [CGColor]
    let farRidge, nearRidge, ground, road, sun, mark, dash, edge: CGColor
    let glow, cloud, pinShade: CGColor
    let carBody, carCabin, windowTop, windowBottom, tailLight, plate: CGColor
}

func palette(_ variant: Variant) -> Palette {
    switch variant {
    case .light:
        Palette(
            sky: [rgb(1.00, 0.74, 0.38), rgb(0.93, 0.42, 0.30), rgb(0.40, 0.20, 0.45), rgb(0.12, 0.14, 0.38)],
            classicSky: [rgb(1.00, 0.74, 0.38), rgb(0.93, 0.42, 0.30), rgb(0.16, 0.20, 0.42)],
            farRidge: rgb(0.42, 0.23, 0.36), nearRidge: rgb(0.24, 0.15, 0.25), ground: rgb(0.16, 0.13, 0.16),
            road: rgb(0.11, 0.11, 0.13), sun: rgb(1.00, 0.714, 0.153), mark: rgb(0.09, 0.098, 0.114),
            dash: rgb(1.00, 0.714, 0.153), edge: rgb(1, 1, 1, 0.55),
            glow: rgb(1.0, 0.75, 0.3, 0.45), cloud: rgb(1.0, 0.55, 0.35, 0.55), pinShade: rgb(0.75, 0.42, 0.05, 0.55),
            carBody: rgb(0.13, 0.15, 0.24), carCabin: rgb(0.10, 0.12, 0.20),
            windowTop: rgb(0.98, 0.55, 0.30, 0.9), windowBottom: rgb(0.30, 0.20, 0.38, 0.95),
            tailLight: rgb(1, 0.18, 0.16), plate: rgb(1.00, 0.714, 0.153)
        )
    case .dark:
        Palette(
            sky: [rgb(0.42, 0.20, 0.30), rgb(0.20, 0.12, 0.30), rgb(0.08, 0.07, 0.18), rgb(0.02, 0.03, 0.08)],
            classicSky: [rgb(0.42, 0.20, 0.30), rgb(0.12, 0.10, 0.26), rgb(0.02, 0.03, 0.08)],
            farRidge: rgb(0.20, 0.13, 0.28), nearRidge: rgb(0.11, 0.08, 0.17), ground: rgb(0.07, 0.06, 0.09),
            road: rgb(0.05, 0.05, 0.07), sun: rgb(1.00, 0.714, 0.153), mark: rgb(0.09, 0.098, 0.114),
            dash: rgb(1.00, 0.714, 0.153), edge: rgb(1, 1, 1, 0.4),
            glow: rgb(1.0, 0.7, 0.25, 0.35), cloud: rgb(0.75, 0.40, 0.45, 0.45), pinShade: rgb(0.75, 0.42, 0.05, 0.55),
            carBody: rgb(0.10, 0.11, 0.17), carCabin: rgb(0.07, 0.08, 0.13),
            windowTop: rgb(0.80, 0.42, 0.30, 0.85), windowBottom: rgb(0.18, 0.12, 0.25, 0.95),
            tailLight: rgb(1, 0.18, 0.16), plate: rgb(1.00, 0.714, 0.153)
        )
    case .tinted:
        Palette(
            sky: [rgb(0.10, 0.10, 0.10), rgb(0.06, 0.06, 0.06), rgb(0.03, 0.03, 0.03), rgb(0, 0, 0)],
            classicSky: [rgb(0.08, 0.08, 0.08), rgb(0, 0, 0)],
            farRidge: rgb(0.22, 0.22, 0.22), nearRidge: rgb(0.15, 0.15, 0.15), ground: rgb(0.10, 0.10, 0.10),
            road: rgb(0.30, 0.30, 0.30), sun: rgb(1, 1, 1), mark: rgb(0, 0, 0),
            dash: rgb(0.85, 0.85, 0.85), edge: rgb(1, 1, 1, 0.5),
            glow: rgb(1, 1, 1, 0.15), cloud: rgb(1, 1, 1, 0.25), pinShade: rgb(0.55, 0.55, 0.55, 0.5),
            carBody: rgb(0.55, 0.55, 0.55), carCabin: rgb(0.45, 0.45, 0.45),
            windowTop: rgb(0.85, 0.85, 0.85, 0.9), windowBottom: rgb(0.35, 0.35, 0.35, 0.95),
            tailLight: rgb(1, 1, 1), plate: rgb(0.9, 0.9, 0.9)
        )
    }
}

// MARK: Pieces (CoreGraphics' y axis points up)

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

/// A sedan seen from behind; `center.y` is where its tyres meet the road.
func car(_ ctx: CGContext, center: CGPoint, width: Double, colors: Palette) {
    let height = width * 0.62
    let base = center.y
    let left = center.x - width / 2

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
        color: colors.tailLight.copy(alpha: 0.35) ?? colors.tailLight
    )

    ctx.setFillColor(rgb(0.03, 0.03, 0.04))
    for side in [-1.0, 1.0] {
        ctx.fill(CGRect(
            x: center.x + side * width * 0.36 - width * 0.08,
            y: base,
            width: width * 0.16,
            height: height * 0.22
        ))
    }

    let body = CGRect(x: left, y: base + height * 0.08, width: width, height: height * 0.46)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: width * 0.09, cornerHeight: width * 0.09, transform: nil))
    ctx.setFillColor(colors.carBody)
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
    ctx.setFillColor(colors.carCabin)
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
    if let sheen = CGGradient(
        colorsSpace: space,
        colors: [colors.windowTop, colors.windowBottom] as CFArray,
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

    let lightY = body.minY + body.height * 0.62
    for side in [-1.0, 1.0] {
        let lamp = CGRect(
            x: side < 0 ? left + width * 0.04 : left + width * 0.71,
            y: lightY,
            width: width * 0.25,
            height: height * 0.075
        )
        glow(
            ctx,
            center: CGPoint(x: lamp.midX, y: lamp.midY),
            radius: width * 0.2,
            color: colors.tailLight.copy(alpha: 0.55) ?? colors.tailLight
        )
        ctx.addPath(CGPath(
            roundedRect: lamp,
            cornerWidth: lamp.height / 2,
            cornerHeight: lamp.height / 2,
            transform: nil
        ))
        ctx.setFillColor(colors.tailLight)
        ctx.fillPath()
    }
    ctx.setFillColor(colors.tailLight.copy(alpha: 0.85) ?? colors.tailLight)
    ctx.fill(CGRect(x: left + width * 0.29, y: lightY + height * 0.025, width: width * 0.42, height: height * 0.02))

    let plate = CGRect(
        x: center.x - width * 0.11,
        y: body.minY + body.height * 0.18,
        width: width * 0.22,
        height: height * 0.1
    )
    ctx.addPath(CGPath(roundedRect: plate, cornerWidth: 6, cornerHeight: 6, transform: nil))
    ctx.setFillColor(colors.plate)
    ctx.fillPath()
}

// MARK: The icons

enum Design { case route, classic }

/// The play mark, in proportion to the circle it sits in.
func play(_ ctx: CGContext, center: CGPoint, radius: Double, color: CGColor) {
    let side = radius * 0.95
    let mid = CGPoint(x: center.x + side * 0.1, y: center.y)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: mid.x + side * 0.55, y: mid.y))
    ctx.addLine(to: CGPoint(x: mid.x - side * 0.45, y: mid.y + side * 0.58))
    ctx.addLine(to: CGPoint(x: mid.x - side * 0.45, y: mid.y - side * 0.58))
    ctx.closePath()
    ctx.setFillColor(color)
    ctx.fillPath()
}

/// AppIcon (DECISIONS 175): the car drives a winding road to a map pin whose head is the play button.
func routeIcon(_ ctx: CGContext, _ colors: Palette) {
    let horizon = size * 0.34
    if let sky = CGGradient(colorsSpace: space, colors: colors.sky as CFArray, locations: [0, 0.3, 0.7, 1]) {
        ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: horizon), end: CGPoint(x: 0, y: size), options: [])
    }
    ctx.setFillColor(colors.cloud)
    for (cloudX, cloudY, cloudW) in [(40.0, 760.0, 250.0), (740.0, 800.0, 250.0), (20.0, 690.0, 160.0), (800.0, 720.0, 190.0)] {
        let cloud = CGRect(x: cloudX, y: cloudY, width: cloudW, height: 22)
        ctx.addPath(CGPath(roundedRect: cloud, cornerWidth: 11, cornerHeight: 11, transform: nil))
        ctx.fillPath()
    }

    let head = CGPoint(x: size / 2, y: size * 0.70)
    let headRadius = 168.0
    glow(ctx, center: head, radius: headRadius * 2.1, color: colors.glow)
    ridge(ctx, horizon: horizon, height: size * 0.14, seed: 1, color: colors.farRidge)
    ridge(ctx, horizon: horizon, height: size * 0.055, seed: 2, color: colors.nearRidge)
    ctx.setFillColor(colors.ground)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: horizon))
    glow(ctx, center: CGPoint(x: size / 2, y: horizon), radius: size * 0.3, color: colors.glow)

    // The winding road is laid flat on the ground and seen in perspective, so its edges never fold over.
    let lateral = 260.0, rise = horizon + 40, roadWidth = 0.9
    func roadX(_ depth: Double) -> Double {
        2.4 * sin(0.62 * (depth - 1)) * min(1, (depth - 1) / 2.5) * exp(-max(0, depth - 7) / 4)
    }
    func project(_ across: Double, _ depth: Double) -> CGPoint {
        CGPoint(x: size / 2 + (roadX(depth) + across) * lateral / depth, y: horizon - rise / depth)
    }
    func strip(_ from: Double, _ to: Double, near: Double, far: Double) {
        let depths = (0...160).map { near * pow(far / near, Double($0) / 160) }
        ctx.beginPath()
        ctx.addLines(between: depths.map { project(from, $0) } + depths.reversed().map { project(to, $0) })
        ctx.closePath()
        ctx.fillPath()
    }
    ctx.setFillColor(colors.road)
    strip(-roadWidth, roadWidth, near: 1, far: 500)
    ctx.setFillColor(colors.edge)
    strip(-roadWidth * 0.90, -roadWidth * 0.84, near: 1, far: 500)
    strip(roadWidth * 0.84, roadWidth * 0.90, near: 1, far: 500)
    ctx.setFillColor(colors.dash)
    var dash = 1.2
    while dash < 80 {
        strip(-0.06, 0.06, near: dash, far: dash + 0.7)
        dash += 1.6
    }
    let depth = 1.35
    car(ctx, center: project(0, depth), width: 0.78 * 2 * roadWidth * lateral / depth, colors: colors)

    // The pin stands where the road meets the horizon.
    let tip = CGPoint(x: size / 2, y: horizon + 4)
    ctx.setFillColor(rgb(0, 0, 0, 0.45))
    ctx.fillEllipse(in: CGRect(x: tip.x - 46, y: tip.y - 9, width: 92, height: 18))
    let spread = acos(headRadius / (head.y - tip.y))
    let pin = CGMutablePath()
    pin.move(to: tip)
    pin.addArc(center: head, radius: headRadius, startAngle: -.pi / 2 + spread, endAngle: .pi * 1.5 - spread, clockwise: false)
    pin.closeSubpath()
    ctx.addPath(pin)
    ctx.setFillColor(colors.sun)
    ctx.fillPath()
    ctx.saveGState()
    ctx.addPath(pin)
    ctx.clip()
    if let shade = CGGradient(
        colorsSpace: space,
        colors: [colors.pinShade, colors.sun.copy(alpha: 0) ?? colors.sun] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawLinearGradient(shade, start: tip, end: CGPoint(x: tip.x, y: head.y - headRadius * 0.2), options: [])
    }
    ctx.restoreGState()
    play(ctx, center: head, radius: headRadius * 0.86, color: colors.mark)
}

/// AppIcon-Classic: the original icon, an empty road to the play-sun.
func classicIcon(_ ctx: CGContext, _ colors: Palette) {
    let horizon = size * 0.40
    if let sky = CGGradient(colorsSpace: space, colors: colors.classicSky as CFArray, locations: nil) {
        ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: horizon), end: CGPoint(x: 0, y: size), options: [])
    }
    let radius = size * 0.2
    let sun = CGRect(x: size / 2 - radius, y: horizon + radius * 0.05, width: radius * 2, height: radius * 2)
    ctx.setFillColor(colors.sun.copy(alpha: 0.2) ?? colors.sun)
    ctx.fillEllipse(in: sun.insetBy(dx: -radius * 0.4, dy: -radius * 0.4))
    ridge(ctx, horizon: horizon, height: size * 0.15, seed: 1, color: colors.farRidge)
    ctx.setFillColor(colors.sun)
    ctx.fillEllipse(in: sun)
    play(ctx, center: CGPoint(x: sun.midX, y: sun.midY), radius: radius, color: colors.mark)
    ridge(ctx, horizon: horizon, height: size * 0.06, seed: 2, color: colors.nearRidge)

    ctx.setFillColor(colors.ground)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: horizon))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: size * 0.48, y: horizon))
    ctx.addLine(to: CGPoint(x: size * 0.52, y: horizon))
    ctx.addLine(to: CGPoint(x: size * 0.98, y: 0))
    ctx.addLine(to: CGPoint(x: size * 0.02, y: 0))
    ctx.closePath()
    ctx.setFillColor(colors.road)
    ctx.fillPath()

    ctx.setStrokeColor(colors.edge)
    ctx.setLineWidth(10)
    for edge in [-1.0, 1.0] {
        ctx.move(to: CGPoint(x: size / 2 + edge * size * 0.02, y: horizon))
        ctx.addLine(to: CGPoint(x: size / 2 + edge * size * 0.44, y: 0))
    }
    ctx.strokePath()

    ctx.setFillColor(colors.dash)
    for index in 0..<8 {
        let far = pow(Double(index) / 8, 2.0)
        let near = pow((Double(index) + 0.5) / 8, 2.0)
        let top = horizon - horizon * far
        let bottom = horizon - horizon * near
        let width = max(4, size * 0.05 * near)
        ctx.fill(CGRect(x: size / 2 - width / 2, y: bottom, width: width, height: top - bottom))
    }
}

func icon(_ variant: Variant, _ design: Design) -> CGImage {
    // App icons must be opaque: no alpha channel.
    guard let ctx = CGContext(
        data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { fatalError("context") }
    switch design {
    case .route: routeIcon(ctx, palette(variant))
    case .classic: classicIcon(ctx, palette(variant))
    }
    guard let image = ctx.makeImage() else { fatalError("image") }
    return image
}

func write(_ image: CGImage, to path: String) throws {
    guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { fatalError("png") }
    try data.write(to: URL(fileURLWithPath: path))
}

let catalog = "Resources/Assets.xcassets"
for (set, design) in [("AppIcon", Design.route), ("AppIcon-Classic", Design.classic)] {
    try write(icon(.light, design), to: "\(catalog)/\(set).appiconset/AppIcon.png")
    try write(icon(.dark, design), to: "\(catalog)/\(set).appiconset/AppIcon-Dark.png")
    try write(icon(.tinted, design), to: "\(catalog)/\(set).appiconset/AppIcon-Tinted.png")
}

// AppLogo: the icon at 256 px for screens that show it, such as onboarding's brand tile.
let logoSide = 256
guard let logo = CGContext(
    data: nil, width: logoSide, height: logoSide, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("logo") }
logo.interpolationQuality = .high
logo.draw(icon(.light, .route), in: CGRect(x: 0, y: 0, width: logoSide, height: logoSide))
guard let logoImage = logo.makeImage() else { fatalError("logo image") }
try write(logoImage, to: "\(catalog)/AppLogo.imageset/AppLogo.png")
