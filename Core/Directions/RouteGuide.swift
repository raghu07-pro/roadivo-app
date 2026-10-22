import Foundation

/// Follows the driver along a route for turn-by-turn guidance on the CarPlay screen (DECISIONS 147).
/// Each step says what to do where its stretch starts, so on step `n` the next maneuver is step `n + 1`.
struct RouteGuide: Sendable {
    struct Progress: Equatable, Sendable {
        /// The step whose stretch the driver is on.
        let step: Int
        /// In metres, to where the next step starts, or to the destination on the last one.
        let distanceToManeuver: Double
        /// In metres.
        let distanceRemaining: Double
        let timeRemaining: TimeInterval
        let hasArrived: Bool
        /// Away from the route for several fixes in a row: time to ask Maps for a new one.
        let isOffRoute: Bool
    }

    /// Where a fix lands on one stretch.
    private struct Match {
        let step: Int
        /// Metres from the stretch's start.
        let along: Double
        /// Metres from the fix to the stretch.
        let gap: Double
    }

    /// Farther than this from the route, in metres, counts as off it.
    static let offRouteDistance = 60.0
    /// Fixes in a row off the route before rerouting, so one jumpy fix doesn't.
    static let offRouteFixes = 3
    /// This close to the destination, in metres, counts as there.
    static let arrivalDistance = 30.0
    /// Stretches ahead a fix may match, so the driver never skips across the route.
    private static let lookAhead = 3
    /// How far back from a junction a heading is read, in metres, so a kink in the line doesn't count as a turn.
    private static let headingSpan = 15.0

    let steps: [RouteStep]
    private let lengths: [Double]
    private let totalLength: Double
    private let travelTime: TimeInterval
    private var step = 0
    private var along = 0.0
    private var fixesOffRoute = 0

    init(route: RouteOption) {
        let stretches = route.steps.filter { !$0.path.isEmpty }
        // A route without steps (the scripted ones) is one stretch straight to the destination.
        steps = stretches.isEmpty
            ? [RouteStep(instructions: "", distance: route.distance, path: route.path)]
            : stretches
        lengths = steps.map { Self.length(of: $0.path) }
        totalLength = lengths.reduce(0, +)
        travelTime = route.travelTime
    }

    var progress: Progress {
        let toManeuver = max(lengths[step] - along, 0)
        let remaining = toManeuver + lengths[(step + 1)...].reduce(0, +)
        return Progress(
            step: step,
            distanceToManeuver: toManeuver,
            distanceRemaining: remaining,
            timeRemaining: totalLength > 0 ? travelTime * remaining / totalLength : 0,
            hasArrived: remaining <= Self.arrivalDistance,
            isOffRoute: fixesOffRoute >= Self.offRouteFixes
        )
    }

    /// Moves to the fix; never backwards, so passing near an earlier stretch doesn't undo a turn.
    mutating func update(at position: Coordinate) -> Progress {
        var best: Match?
        for index in step..<min(step + Self.lookAhead, steps.count) {
            let match = Self.match(position, step: index, path: steps[index].path)
            // A later stretch wins only when clearly closer, so a fix at a junction stays before the turn.
            if best.map({ match.gap < $0.gap - 1 }) ?? true {
                best = match
            }
        }
        if let best, best.gap <= Self.offRouteDistance {
            step = best.step
            along = best.along
            fixesOffRoute = 0
        } else {
            fixesOffRoute += 1
        }
        return progress
    }

    /// Which way step `index` turns from the stretch before it; `.arrive` past the last step.
    func turn(into index: Int) -> TurnKind {
        guard index < steps.count else { return .arrive }
        guard index > 0, let before = Self.headingIn(steps[index - 1].path) else {
            // Maps' first step is the start point itself, so there's no road behind the car yet.
            return index <= 1 ? .start : .straight
        }
        guard let after = Self.headingOut(steps[index].path) else { return .straight }
        return TurnKind(from: before, to: after)
    }

    // MARK: Geometry

    private static func match(_ position: Coordinate, step: Int, path: [Coordinate]) -> Match {
        guard let first = path.first else { return Match(step: step, along: 0, gap: .infinity) }
        var best = Match(step: step, along: 0, gap: position.distance(to: first))
        var travelled = 0.0
        for (start, end) in zip(path, path.dropFirst()) {
            let from = start.offset(from: position)
            let to = end.offset(from: position)
            let east = to.east - from.east
            let north = to.north - from.north
            let squared = east * east + north * north
            // Where the segment passes closest to the fix: 0 at its start, 1 at its end.
            let fraction = squared > 0 ? min(max(-(from.east * east + from.north * north) / squared, 0), 1) : 0
            let gap = hypot(from.east + fraction * east, from.north + fraction * north)
            if gap < best.gap {
                best = Match(step: step, along: travelled + fraction * squared.squareRoot(), gap: gap)
            }
            travelled += squared.squareRoot()
        }
        return best
    }

    private static func length(of path: [Coordinate]) -> Double {
        zip(path, path.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
    }

    /// The heading arriving at the end of `path`.
    private static func headingIn(_ path: [Coordinate]) -> Double? {
        guard let end = path.last else { return nil }
        let earlier = path.dropLast()
        guard let start = earlier.last(where: { $0.distance(to: end) >= headingSpan }) ?? earlier.first,
              start.distance(to: end) > 1
        else { return nil }
        return start.bearing(to: end)
    }

    /// The heading leaving the start of `path`.
    private static func headingOut(_ path: [Coordinate]) -> Double? {
        guard let start = path.first else { return nil }
        let later = path.dropFirst()
        guard let end = later.first(where: { start.distance(to: $0) >= headingSpan }) ?? later.last,
              start.distance(to: end) > 1
        else { return nil }
        return start.bearing(to: end)
    }
}
