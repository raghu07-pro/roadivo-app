import SwiftUI

/// Roadivo's opening (owner, 2026-10-20; DECISIONS 130). From the launch screen's plain indigo, the road comes up
/// as it is outside (sunrise, midday, sunset, or night with stars) with the logo's idea in it: the sun, or the
/// moon at night, is a play button, in that hour's own colours. In the morning it rises from behind the mountains;
/// in the evening it sinks and sets behind them. The logo's car rolls along the road below; no words (owner). Then
/// the play-sun "presses play" into the app. About two seconds; a tap skips it; with Reduce Motion it only fades.
struct SplashView: View {
    /// Called once it has faded out; the app is already underneath.
    let onFinish: () -> Void
    /// Off for previews and snapshot tests, which show the settled frame.
    var isAnimated = true
    /// The time of day it shows; the hour the app opens, unless a test or preview picks one.
    var moment = SplashMoment(date: .now)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsStars = false
    @State private var isSettled = false
    @State private var isSunUp = false
    @State private var showsPlay = false
    @State private var isBobbing = false
    @State private var isLeaving = false

    /// UI tests skip it (it would cover the first taps) unless they ask for it. So does the app when it only hosts
    /// the unit tests: its exit would land mid-snapshot and redraw the key window the snapshots render in.
    static func isWanted(arguments: [String], environment: [String: String] = [:]) -> Bool {
        #if DEBUG
            if environment["XCTestConfigurationFilePath"] != nil {
                return false
            }
            if arguments.contains("-ui-testing") {
                return arguments.contains("-show-splash")
            }
        #endif
        return true
    }

    var body: some View {
        let settled = isSettled || !isAnimated
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Color("LaunchBackground")
                RoadScene(time: moment.time, horizon: 0.7, animated: false, showsOrb: false, layers: .sky)
                    .opacity(settled ? 1 : 0)
                // Deepens the top of the sky: night indigo, or a midday blue.
                LinearGradient(
                    colors: [moment.skyShade, moment.skyShade.opacity(0)],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.5)
                )
                .opacity(settled ? 0.8 : 0)
                if moment == .midday {
                    SplashClouds(isDrifting: isAnimated && !reduceMotion)
                        .opacity(settled ? 1 : 0)
                }
                // They fade with the sunrise, and stay out at night.
                SplashStars(isTwinkling: isAnimated && !reduceMotion)
                    .opacity(showsStars && (!settled || moment == .night) ? 1 : 0)
                playSun(in: size)
                // The mountains and road over the sun, so it rises and sets behind them.
                RoadScene(time: moment.time, horizon: 0.7, animated: isAnimated, layers: .land)
                    .opacity(settled ? 1 : 0)
                car(in: size)
            }
        }
        .opacity(isLeaving ? 0 : 1)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { leave() }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: showsPlay) { _, shown in
            shown && isAnimated
        }
        .task { await play() }
        .accessibilityHidden(true) // Decorative; VoiceOver starts on the app itself.
        .accessibilityIdentifier("splash")
    }

    // MARK: Parts

    /// The sun (or moon) as a play button above the road, in the hour's own colours. In the morning it rises from
    /// behind the mountains, in the evening it sinks toward them and sets behind them on the way out; at midday and
    /// night it blooms in. Its play mark pops up, and on the way out (but at sunset) it opens across the screen.
    private func playSun(in size: CGSize) -> some View {
        let moves = !reduceMotion
        let settled = isSettled || !isAnimated
        let isUp = isSunUp || !isAnimated
        let marked = showsPlay || !isAnimated
        let radius = min(size.width * 0.17, size.height * 0.13)
        let colours = moment.sun
        let rest = size.height * 0.46
        let behindMountains = size.height * 0.7 + radius * 1.3
        let centre: CGFloat = switch moment {
        case .sunrise: isUp || !moves ? rest : behindMountains
        case .sunset: isLeaving && moves ? behindMountains : (isUp || !moves ? rest : size.height * 0.36)
        case .midday, .night: rest
        }
        let blooms = moment == .midday || moment == .night
        return ZStack {
            Circle() // Its own soft light, in its own colour: no halo of another hue.
                .fill(RadialGradient(
                    colors: [colours.light.opacity(0.35), colours.light.opacity(0)],
                    center: .center,
                    startRadius: radius * 0.9,
                    endRadius: radius * 2.1
                ))
                .frame(width: radius * 4.2, height: radius * 4.2)
            Circle()
                .fill(colours.light)
                .frame(width: radius * 2, height: radius * 2)
            PlayMark()
                .fill(colours.mark)
                .frame(width: radius * 0.8, height: radius * 0.9)
                .offset(x: radius * 0.08)
                .scaleEffect(marked || !moves ? 1 : 0.3)
                .opacity(marked ? 1 : 0)
        }
        .scaleEffect(isLeaving && moves && moment != .sunset ? 9 : (blooms && !isUp && moves ? 0.6 : 1))
        // The evening sun is up from the start; the others appear as they rise or bloom, never through the hills.
        .opacity((moment == .sunset ? settled : isUp) ? 1 : 0)
        .position(x: size.width / 2, y: centre)
    }

    /// The logo's car on the road: it drives up into place as the road comes in, bobs as it goes, and drives off
    /// toward the horizon on the way out.
    private func car(in size: CGSize) -> some View {
        let moves = !reduceMotion
        let settled = isSettled || !isAnimated
        let width = min(size.width * 0.34, size.height * 0.2)
        let centre: CGFloat = if isLeaving && moves {
            size.height * 0.73
        } else if settled || !moves {
            size.height * 0.86
        } else {
            size.height + width
        }
        return SplashCar()
            .frame(width: width, height: width * 0.62)
            .scaleEffect(isLeaving && moves ? 0.25 : 1)
            .offset(y: isBobbing && !isLeaving ? -1.2 : 0)
            .opacity(settled ? 1 : 0)
            .position(x: size.width / 2, y: centre)
            .animation(isLeaving ? nil : .spring(duration: 0.9, bounce: 0.15), value: settled)
    }

    // MARK: Timing

    private func play() async {
        guard isAnimated else { return }
        let moves = !reduceMotion
        withAnimation(.easeOut(duration: 0.3)) {
            showsStars = true
        }
        // A sleep only throws when the splash goes away early (a tap), which has already left.
        try? await Task.sleep(for: .seconds(0.1))
        withAnimation(.easeOut(duration: 0.5)) {
            isSettled = true // The sky and road fade in.
        }
        let crosses = moment == .sunrise || moment == .sunset // The sun moves past the mountains.
        if crosses {
            try? await Task.sleep(for: .seconds(0.2))
        }
        withAnimation(sunMotion) {
            isSunUp = true
        }
        try? await Task.sleep(for: .seconds(moves && moment == .sunrise ? 0.95 : 0.45)) // Once the sun clears them.
        withAnimation(moves ? .spring(duration: 0.4, bounce: 0.5) : .easeOut(duration: 0.3)) {
            showsPlay = true
        }
        if moves {
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                isBobbing = true // The car rolling along.
            }
        }
        try? await Task.sleep(for: .seconds(moves ? 0.9 : 1.0))
        leave()
    }

    /// Slow for the sun rising or setting, springy for the midday sun and the moon blooming in.
    private var sunMotion: Animation {
        guard !reduceMotion else { return .easeOut(duration: 0.4) }
        return switch moment {
        case .sunrise: .easeOut(duration: 1.1)
        case .sunset: .easeInOut(duration: 1.0)
        case .midday, .night: .spring(duration: 0.8, bounce: 0.3)
        }
    }

    private func leave() {
        guard !isLeaving else { return }
        // At sunset the sun sinks behind the mountains as it fades; otherwise the play-sun opens out.
        withAnimation(.easeIn(duration: reduceMotion ? 0.3 : (moment == .sunset ? 0.7 : 0.5))) {
            isLeaving = true
        } completion: {
            onFinish()
        }
    }
}

/// The logo's play mark: a rounded triangle pointing right.
private struct PlayMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path.strokedPath(StrokeStyle(lineWidth: rect.width * 0.12, lineJoin: .round)).union(path)
    }
}

/// The splash's road at the hour the app opens (owner, 2026-10-20): sunrise in the morning, the sun at midday,
/// sunset in the evening, and the moon and stars at night.
enum SplashMoment: CaseIterable {
    case sunrise
    case midday
    case sunset
    case night

    /// The play-button sun's colours: its light and its play mark.
    struct Sun {
        let light: Color
        let mark: Color
    }

    init(date: Date, calendar: Calendar = .current) {
        switch calendar.component(.hour, from: date) {
        case 5..<11: self = .sunrise
        case 11..<17: self = .midday
        case 17..<20: self = .sunset
        default: self = .night
        }
    }

    var time: RoadScene.TimeOfDay {
        switch self {
        case .sunrise: .goldenHour
        case .midday: .day
        case .sunset: .dusk
        case .night: .night
        }
    }

    /// The sun in the hour's own colours: golden at sunrise, bright at midday, coral at sunset, the silver moon at
    /// night; each play mark is the deep colour of that sky.
    var sun: Sun {
        switch self {
        case .sunrise:
            Sun(light: Color(red: 1.0, green: 0.82, blue: 0.47), mark: Color(red: 0.24, green: 0.2, blue: 0.42))
        case .midday:
            Sun(light: Color(red: 1.0, green: 0.93, blue: 0.62), mark: Color(red: 0.12, green: 0.36, blue: 0.68))
        case .sunset:
            Sun(light: Color(red: 1.0, green: 0.64, blue: 0.48), mark: Color(red: 0.32, green: 0.15, blue: 0.36))
        case .night:
            Sun(light: Color(red: 0.93, green: 0.94, blue: 0.9), mark: Color(red: 0.1, green: 0.12, blue: 0.28))
        }
    }

    /// The top of the sky: the launch screen's indigo, or a deep midday blue.
    var skyShade: Color {
        self == .midday ? Color(red: 0.10, green: 0.36, blue: 0.72) : Color("LaunchBackground")
    }
}

/// The midday sky's two small clouds, high up; they drift unless Reduce Motion is on.
private struct SplashClouds: View {
    private struct Cloud {
        let left: Double
        let top: Double
        let scale: Double
        let speed: Double
    }

    let isDrifting: Bool

    private static let clouds = [
        Cloud(left: 0.03, top: 0.09, scale: 0.6, speed: 8),
        Cloud(left: 0.66, top: 0.12, scale: 0.7, speed: 11)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isDrifting)) { context in
            let time = isDrifting ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600) : 0
            Canvas { canvas, size in
                for cloud in Self.clouds {
                    let width = size.width * 0.34 * cloud.scale
                    let travel = size.width + width
                    let left = (cloud.left * size.width + time * cloud.speed).truncatingRemainder(dividingBy: travel)
                    canvas.fill(
                        Self.shape(left: left - width * 0.1, top: cloud.top * size.height, width: width),
                        with: .color(.white.opacity(0.9))
                    )
                }
            }
        }
    }

    /// A flat-bottomed puff: a long base with two rounded tops.
    private static func shape(left: Double, top: Double, width: Double) -> Path {
        var path = Path(
            roundedRect: CGRect(x: left, y: top, width: width, height: width * 0.3),
            cornerRadius: width * 0.15
        )
        path.addEllipse(in: CGRect(
            x: left + width * 0.16,
            y: top - width * 0.18,
            width: width * 0.36,
            height: width * 0.36
        ))
        path.addEllipse(in: CGRect(
            x: left + width * 0.42,
            y: top - width * 0.26,
            width: width * 0.44,
            height: width * 0.44
        ))
        return path
    }
}

/// The night sky: fixed stars (the same every launch) that twinkle unless Reduce Motion is on.
private struct SplashStars: View {
    private struct Star {
        let left: Double
        let top: Double
        let size: Double
        let phase: Double
    }

    let isTwinkling: Bool

    private static let stars: [Star] = {
        var seed: UInt64 = 0x524F_4144 // "ROAD"
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 33) / Double(UInt64(1) << 31)
        }
        return (0..<46).map { _ in Star(left: next(), top: next() * 0.55, size: 1 + next() * 2, phase: next()) }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !isTwinkling)) { context in
            let time = isTwinkling ? context.date.timeIntervalSinceReferenceDate : 0
            Canvas { canvas, size in
                for star in Self.stars {
                    let glow = isTwinkling ? 0.45 + 0.55 * abs(sin(time * 2.2 + star.phase * 6.3)) : 0.8
                    let rect = CGRect(
                        x: star.left * size.width,
                        y: star.top * size.height,
                        width: star.size,
                        height: star.size
                    )
                    canvas.fill(Path(ellipseIn: rect), with: .color(.white.opacity(glow)))
                }
            }
        }
    }
}

#Preview("Animated") {
    SplashView(onFinish: {})
}

#Preview("Settled at midday") {
    SplashView(onFinish: {}, isAnimated: false, moment: .midday)
}

#Preview("Settled at night") {
    SplashView(onFinish: {}, isAnimated: false, moment: .night)
}
