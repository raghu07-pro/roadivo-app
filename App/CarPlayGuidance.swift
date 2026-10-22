import CarPlay
import OSLog

/// Turn-by-turn on the CarPlay screen (DECISIONS 147): follows the iPhone's fixes along the route, keeps CarPlay's
/// maneuver card, distances and arrival time current, and asks Maps for a new route when the driver leaves it.
@MainActor
final class CarPlayGuidance {
    private let session: CPNavigationSession
    private let mapTemplate: CPMapTemplate
    private let destination: Place
    private let finder: PlaceFinding
    private let location: LocationProviding
    private let map: CarPlayMapViewController
    /// Called once the driver arrives; the scene then goes back to its map.
    private let onArrival: () -> Void
    private var guide: RouteGuide
    /// The step whose maneuvers CarPlay is showing, so they're only replaced at a new step.
    private var shownStep: Int?
    private var updates: Task<Void, Never>?
    private var isRerouting = false
    private var lastReroute: Date?
    private let usesMiles = RoadDistance.usesMiles(in: AppLocale.current)
    private let logger = Logger(subsystem: "com.roadivo", category: "CarPlay")
    /// Seconds between attempts at a new route, so a long detour doesn't ask Maps on every fix.
    private static let rerouteInterval: TimeInterval = 15

    init(
        session: CPNavigationSession,
        mapTemplate: CPMapTemplate,
        route: RouteOption,
        destination: Place,
        environment: AppEnvironment,
        map: CarPlayMapViewController,
        onArrival: @escaping () -> Void
    ) {
        self.session = session
        self.mapTemplate = mapTemplate
        self.destination = destination
        finder = environment.places
        location = environment.location
        self.map = map
        self.onArrival = onArrival
        guide = RouteGuide(route: route)
        map.guide(along: route, to: destination)
    }

    func start() {
        show(guide.progress)
        updates = Task { [weak self, location] in
            for await position in location.updates() {
                guard let self else { return }
                await moved(to: position)
            }
        }
    }

    /// Stops following the iPhone, as when the car disconnects.
    func stop() {
        updates?.cancel()
        updates = nil
    }

    /// The driver ended the route: CarPlay drops the maneuver card.
    func cancel() {
        stop()
        session.cancelTrip()
    }

    private func moved(to position: Coordinate) async {
        guard !isRerouting else { return }
        let progress = guide.update(at: position)
        if progress.hasArrived {
            stop()
            session.finishTrip()
            onArrival()
        } else if progress.isOffRoute {
            await reroute(from: position)
        } else {
            show(progress)
        }
    }

    private func show(_ progress: RouteGuide.Progress) {
        let perMetre = progress.distanceRemaining > 0 ? progress.timeRemaining / progress.distanceRemaining : 0
        if progress.step != shownStep {
            shownStep = progress.step
            // The next two maneuvers; past the last step comes the arrival.
            let next = progress.step + 1
            session.upcomingManeuvers = (next...(next + 1)).filter { $0 <= guide.steps.count }.map { index in
                let distance = index == next ? progress.distanceToManeuver : guide.steps[index - 1].distance
                return maneuver(at: index, distance: distance, time: distance * perMetre)
            }
        }
        if let current = session.upcomingManeuvers.first {
            session.updateEstimates(
                estimates(progress.distanceToManeuver, time: progress.distanceToManeuver * perMetre),
                for: current
            )
        }
        mapTemplate.updateEstimates(
            estimates(progress.distanceRemaining, time: progress.timeRemaining),
            for: session.trip
        )
    }

    private func maneuver(at index: Int, distance: Double, time: TimeInterval) -> CPManeuver {
        let maneuver = CPManeuver()
        let turn = guide.turn(into: index)
        maneuver.instructionVariants = [
            index < guide.steps.count
                ? guide.steps[index].instructions
                : String(appLocalized: "Arrive at \(destination.name)")
        ]
        maneuver.symbolImage = turn.cardSymbol
        if #available(iOS 17.4, *) {
            maneuver.maneuverType = turn.maneuverType
        }
        maneuver.initialTravelEstimates = estimates(distance, time: time)
        maneuver.userInfo = index
        return maneuver
    }

    private func estimates(_ meters: Double, time: TimeInterval) -> CPTravelEstimates {
        CPTravelEstimates(
            distanceRemaining: RoadDistance.measurement(meters: meters, usesMiles: usesMiles),
            timeRemaining: time
        )
    }

    /// A new route from here, the fastest Maps finds; CarPlay shows "rerouting" meanwhile.
    private func reroute(from position: Coordinate) async {
        if let lastReroute, Date.now.timeIntervalSince(lastReroute) < Self.rerouteInterval {
            return
        }
        lastReroute = .now
        isRerouting = true
        defer { isRerouting = false }
        // Shown again in full once a route comes back, or once the driver is back on the old one.
        shownStep = nil
        session.pauseTrip(for: .rerouting, description: String(appLocalized: "Finding a new route…"))
        do {
            guard let route = try await finder.routes(from: position, to: destination).first, updates != nil else {
                return
            }
            guide = RouteGuide(route: route)
            map.guide(along: route, to: destination)
            show(guide.update(at: position))
        } catch {
            logger.error("Reroute: \(error.localizedDescription, privacy: .public)")
        }
    }
}
