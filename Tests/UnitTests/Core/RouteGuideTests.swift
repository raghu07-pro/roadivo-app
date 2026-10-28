import Foundation
import Testing
@testable import PlayCarTV

/// An L-shaped drive: 500 m north from the start, then right for 400 m to the place, 90 s in all.
@Suite("Route guide")
struct RouteGuideTests {
    private static let start = Coordinate(latitude: 38.7, longitude: -9.1)
    private static let corner = point(north: 500, east: 0)
    private static let end = point(north: 500, east: 400)

    private static let route = RouteOption(
        id: 0,
        name: "Rua B",
        distance: 900,
        travelTime: 90,
        path: [start, corner, end],
        steps: [
            RouteStep(instructions: "", distance: 0, path: [start]),
            RouteStep(instructions: "Head north on Rua A", distance: 500, path: [start, corner]),
            RouteStep(instructions: "Turn right onto Rua B", distance: 400, path: [corner, end]),
            RouteStep(instructions: "The destination is on your left", distance: 0, path: [end])
        ]
    )

    /// A point this many metres north and east of the start.
    private static func point(north: Double, east: Double) -> Coordinate {
        let metresPerDegree = 6_371_000 * Double.pi / 180
        return Coordinate(
            latitude: start.latitude + north / metresPerDegree,
            longitude: start.longitude + east / (metresPerDegree * cos(start.latitude * .pi / 180))
        )
    }

    @Test("Before any fix the whole route is ahead, from its first step")
    func startsAtTheStart() {
        let progress = RouteGuide(route: Self.route).progress
        #expect(progress.step == 0)
        #expect(abs(progress.distanceRemaining - 900) < 1)
        #expect(abs(progress.timeRemaining - 90) < 0.5)
        #expect(!progress.hasArrived)
        #expect(!progress.isOffRoute)
    }

    @Test("Driving up the first road counts down to the right turn")
    func countsDownToTheTurn() {
        var guide = RouteGuide(route: Self.route)
        let progress = guide.update(at: Self.point(north: 100, east: 0))
        #expect(progress.step == 1)
        #expect(abs(progress.distanceToManeuver - 400) < 1)
        #expect(abs(progress.distanceRemaining - 800) < 1)
        #expect(abs(progress.timeRemaining - 80) < 0.5)
    }

    @Test("A fix right at the junction stays before the turn")
    func junctionStaysBeforeTheTurn() {
        var guide = RouteGuide(route: Self.route)
        let progress = guide.update(at: Self.corner)
        #expect(progress.step == 1)
        #expect(progress.distanceToManeuver < 1)
    }

    @Test("After the turn the next maneuver is the arrival")
    func movesOnAfterTheTurn() {
        var guide = RouteGuide(route: Self.route)
        _ = guide.update(at: Self.point(north: 100, east: 0))
        let progress = guide.update(at: Self.point(north: 500, east: 100))
        #expect(progress.step == 2)
        #expect(abs(progress.distanceToManeuver - 300) < 1)
        #expect(abs(progress.timeRemaining - 30) < 0.5)
    }

    @Test("A fix near an earlier road doesn't undo a turn")
    func neverGoesBackwards() {
        var guide = RouteGuide(route: Self.route)
        _ = guide.update(at: Self.point(north: 500, east: 100))
        let progress = guide.update(at: Self.point(north: 300, east: 0))
        #expect(progress.step == 2)
        #expect(!progress.isOffRoute)
    }

    @Test("Within 30 m of the place counts as arrived")
    func arrives() {
        var guide = RouteGuide(route: Self.route)
        #expect(!guide.update(at: Self.point(north: 500, east: 300)).hasArrived)
        #expect(guide.update(at: Self.point(north: 500, east: 380)).hasArrived)
    }

    @Test("Three fixes in a row away from the route call for a new one")
    func offRouteAfterThreeFixes() {
        var guide = RouteGuide(route: Self.route)
        _ = guide.update(at: Self.point(north: 100, east: 0))
        let away = Self.point(north: 200, east: 200)
        #expect(!guide.update(at: away).isOffRoute)
        #expect(!guide.update(at: away).isOffRoute)
        #expect(guide.update(at: away).isOffRoute)
    }

    @Test("Coming back to the route resets the count")
    func backOnRouteResets() {
        var guide = RouteGuide(route: Self.route)
        let away = Self.point(north: 200, east: 200)
        _ = guide.update(at: away)
        _ = guide.update(at: away)
        #expect(!guide.update(at: Self.point(north: 250, east: 0)).isOffRoute)
        #expect(!guide.update(at: away).isOffRoute)
    }

    @Test("Turns are read from the roads' shape; the first is the start, past the last step the arrival")
    func turns() {
        let guide = RouteGuide(route: Self.route)
        #expect(guide.turn(into: 1) == .start)
        #expect(guide.turn(into: 2) == .right)
        #expect(guide.turn(into: 4) == .arrive)
    }

    @Test("A route without steps is one stretch to the place")
    func routeWithoutSteps() {
        let plain = RouteOption(
            id: 1, name: "", distance: 1000, travelTime: 60, path: [Self.start, Self.point(north: 1000, east: 0)]
        )
        let guide = RouteGuide(route: plain)
        #expect(guide.steps.count == 1)
        #expect(abs(guide.progress.distanceRemaining - 1000) < 1)
    }

    @Test("Scripted routes carry steps for guidance in UI tests")
    func scriptedRoutesHaveSteps() async throws {
        let routes = try await ScriptedPlaceFinder().routes(
            from: ScriptedLocation.lisbon, to: ScriptedPlaceFinder.places[0]
        )
        #expect(routes.allSatisfy { !$0.steps.isEmpty })
    }
}
