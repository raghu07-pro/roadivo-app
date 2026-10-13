import SwiftUI

/// The view through the windshield: sky, sun or moon, two mountain ranges and
/// a road running to the horizon with a yellow centre line. Drawn in code, so
/// it's original art that scales to any size; the lane dashes roll forward
/// unless Reduce Motion is on.
struct RoadScene: View {
    enum TimeOfDay {
        case goldenHour
        case dusk
        case day
        case night
    }

    var time: TimeOfDay = .goldenHour
    /// Where the horizon sits, as a fraction of the height.
    var horizon: CGFloat = 0.55
    var animated = true
    /// The logo's idea: the sun on the horizon is a play button. Centred
    /// over the road.
    var sunIsPlayButton = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !animated)) { context in
            let phase = (reduceMotion || !animated)
                ? 0
                : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
            Canvas { canvas, size in
                draw(in: &canvas, size: size, phase: phase)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Drawing

    private func draw(in canvas: inout GraphicsContext, size: CGSize, phase: Double) {
        let horizonY = size.height * horizon
        let colors = palette

        canvas.fill(
            Path(CGRect(origin: .zero, size: CGSize(width: size.width, height: horizonY + 1))),
            with: .linearGradient(
                Gradient(colors: colors.sky),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: horizonY)
            )
        )

        // Sun or moon, half sunk behind the far range.
        let radius = min(size.width, size.height) * 0.13
        // As the logo, the sun sits higher and centred, so the play mark shows.
        let orb = CGRect(
            x: (sunIsPlayButton ? size.width * 0.5 : size.width * 0.62) - radius,
            y: horizonY - radius * (sunIsPlayButton ? 2.3 : 1.25),
            width: radius * 2,
            height: radius * 2
        )
        canvas.fill(
            Path(ellipseIn: orb.insetBy(dx: -radius * 0.6, dy: -radius * 0.6)),
            with: .color((sunIsPlayButton ? Color.roadLane : colors.orb).opacity(0.18))
        )
        canvas.fill(Path(ellipseIn: orb), with: .color(sunIsPlayButton ? Color.roadLane : colors.orb))
        if sunIsPlayButton {
            drawPlayMark(in: &canvas, orb: orb)
        }

        if time == .night {
            drawStars(in: &canvas, width: size.width, horizonY: horizonY)
        }

        canvas.fill(
            ridge(size: size, base: horizonY, height: size.height * 0.16, seed: 1),
            with: .color(colors.farRidge)
        )
        canvas.fill(
            ridge(size: size, base: horizonY, height: size.height * 0.09, seed: 2),
            with: .color(colors.nearRidge)
        )

        drawRoad(in: &canvas, size: size, horizonY: horizonY, colors: colors, phase: phase)
    }

    private func drawPlayMark(in canvas: inout GraphicsContext, orb: CGRect) {
        let side = orb.width * 0.42
        let center = CGPoint(x: orb.midX + side * 0.1, y: orb.midY)
        var triangle = Path()
        triangle.move(to: CGPoint(x: center.x + side * 0.55, y: center.y))
        triangle.addLine(to: CGPoint(x: center.x - side * 0.45, y: center.y - side * 0.58))
        triangle.addLine(to: CGPoint(x: center.x - side * 0.45, y: center.y + side * 0.58))
        triangle.closeSubpath()
        canvas.fill(triangle, with: .color(Color.roadAsphalt))
    }

    private func drawStars(in canvas: inout GraphicsContext, width: CGFloat, horizonY: CGFloat) {
        for index in 0..<24 {
            let starX = Double((index * 7919) % 1000) / 1000 * width
            let starY = Double((index * 104_729) % 1000) / 1000 * horizonY * 0.8
            canvas.fill(
                Path(ellipseIn: CGRect(x: starX, y: starY, width: 2, height: 2)),
                with: .color(.white.opacity(0.7))
            )
        }
    }

    private func drawRoad(
        in canvas: inout GraphicsContext,
        size: CGSize,
        horizonY: CGFloat,
        colors: Colors,
        phase: Double
    ) {
        canvas.fill(
            Path(CGRect(x: 0, y: horizonY, width: size.width, height: size.height - horizonY)),
            with: .color(colors.ground)
        )
        let vanish = CGPoint(x: size.width / 2, y: horizonY)
        var road = Path()
        road.move(to: CGPoint(x: vanish.x - size.width * 0.012, y: horizonY))
        road.addLine(to: CGPoint(x: vanish.x + size.width * 0.012, y: horizonY))
        road.addLine(to: CGPoint(x: size.width * 0.98, y: size.height))
        road.addLine(to: CGPoint(x: size.width * 0.02, y: size.height))
        road.closeSubpath()
        canvas.fill(road, with: .color(colors.road))

        // White edge lines.
        for side in [-1.0, 1.0] {
            var edge = Path()
            edge.move(to: CGPoint(x: vanish.x + side * size.width * 0.01, y: horizonY))
            edge.addLine(to: CGPoint(x: size.width / 2 + side * size.width * 0.44, y: size.height))
            canvas.stroke(edge, with: .color(.white.opacity(0.55)), lineWidth: 2)
        }

        // Yellow centre dashes in perspective, rolling toward the viewer.
        let depth = size.height - horizonY
        var position = phase
        while position < 12 {
            let near = pow((position + 0.5) / 12, 2.2)
            let far = pow(position / 12, 2.2)
            let top = horizonY + depth * far
            let bottom = horizonY + depth * near
            let width = max(1, size.width * 0.018 * near)
            canvas.fill(
                Path(CGRect(x: vanish.x - width / 2, y: top, width: width, height: max(1, bottom - top))),
                with: .color(Color.roadLane)
            )
            position += 1
        }
    }

    private func ridge(size: CGSize, base: CGFloat, height: CGFloat, seed: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: base))
        let steps = 48
        for step in 0...steps {
            let pointX = size.width * Double(step) / Double(steps)
            let angle = Double(step) / Double(steps) * .pi * 2
            let wave = sin(angle * (1.3 + seed * 0.4) + seed) * 0.55 + sin(angle * (3.1 + seed) + seed * 2) * 0.3
            path.addLine(to: CGPoint(x: pointX, y: base - height * (0.55 + wave * 0.45)))
        }
        path.addLine(to: CGPoint(x: size.width, y: base))
        path.closeSubpath()
        return path
    }

    private struct Colors {
        let sky: [Color]
        let orb: Color
        let farRidge: Color
        let nearRidge: Color
        let ground: Color
        let road: Color
    }

    private var palette: Colors {
        switch time {
        case .goldenHour:
            Colors(
                sky: [
                    Color(red: 0.16, green: 0.20, blue: 0.42),
                    Color(red: 0.93, green: 0.42, blue: 0.30),
                    Color(red: 1.00, green: 0.74, blue: 0.38)
                ],
                orb: Color(red: 1.00, green: 0.86, blue: 0.55),
                farRidge: Color(red: 0.42, green: 0.23, blue: 0.36),
                nearRidge: Color(red: 0.24, green: 0.15, blue: 0.25),
                ground: Color(red: 0.16, green: 0.13, blue: 0.16),
                road: Color(red: 0.11, green: 0.11, blue: 0.13)
            )
        case .dusk:
            Colors(
                sky: [
                    Color(red: 0.08, green: 0.09, blue: 0.24),
                    Color(red: 0.47, green: 0.20, blue: 0.45),
                    Color(red: 0.95, green: 0.45, blue: 0.40)
                ],
                orb: Color(red: 1.00, green: 0.66, blue: 0.48),
                farRidge: Color(red: 0.25, green: 0.15, blue: 0.33),
                nearRidge: Color(red: 0.14, green: 0.10, blue: 0.21),
                ground: Color(red: 0.10, green: 0.09, blue: 0.13),
                road: Color(red: 0.08, green: 0.08, blue: 0.10)
            )
        case .day:
            Colors(
                sky: [Color(red: 0.30, green: 0.62, blue: 0.90), Color(red: 0.70, green: 0.86, blue: 0.96)],
                orb: Color(red: 1.00, green: 0.97, blue: 0.85),
                farRidge: Color(red: 0.36, green: 0.55, blue: 0.62),
                nearRidge: Color(red: 0.20, green: 0.42, blue: 0.32),
                ground: Color(red: 0.24, green: 0.42, blue: 0.26),
                road: Color(red: 0.20, green: 0.21, blue: 0.23)
            )
        case .night:
            Colors(
                sky: [Color(red: 0.02, green: 0.03, blue: 0.08), Color(red: 0.09, green: 0.11, blue: 0.24)],
                orb: Color(red: 0.92, green: 0.93, blue: 0.86),
                farRidge: Color(red: 0.10, green: 0.12, blue: 0.22),
                nearRidge: Color(red: 0.06, green: 0.07, blue: 0.13),
                ground: Color(red: 0.04, green: 0.05, blue: 0.07),
                road: Color(red: 0.07, green: 0.07, blue: 0.09)
            )
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        RoadScene(time: .goldenHour)
        RoadScene(time: .dusk)
        RoadScene(time: .day)
        RoadScene(time: .night)
    }
    .ignoresSafeArea()
}
