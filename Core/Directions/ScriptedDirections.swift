import Foundation
import Observation

/// UI tests' and previews' location: a fixed spot in Lisbon, or Location turned off.
@MainActor
@Observable
final class ScriptedLocation: LocationProviding {
    private(set) var status: LocationStatus
    private(set) var lastCoordinate: Coordinate?
    /// What a first `requestAccess()` answers, as if the user tapped Allow or Don't Allow.
    private let allows: Bool
    static let lisbon = Coordinate(latitude: 38.7223, longitude: -9.1393)

    init(status: LocationStatus = .allowed, allows: Bool = true) {
        self.status = status
        self.allows = allows
        lastCoordinate = status == .allowed ? Self.lisbon : nil
    }

    func requestAccess() {
        guard status == .notAsked else { return }
        status = allows ? .allowed : .denied
        lastCoordinate = allows ? Self.lisbon : nil
    }

    func currentCoordinate() async -> Coordinate? {
        requestAccess()
        return status == .allowed ? Self.lisbon : nil
    }
}

/// UI tests' and previews' Apple Maps: two places for any search, two routes to either, no network.
struct ScriptedPlaceFinder: PlaceFinding {
    static let places = [
        Place(
            name: "Cabo da Roca",
            address: "Colares, Sintra",
            coordinate: Coordinate(latitude: 38.7804, longitude: -9.4989)
        ),
        Place(name: "Cascais Marina", address: "Cascais", coordinate: Coordinate(latitude: 38.6912, longitude: -9.4167))
    ]

    func places(matching query: String, near: Coordinate?) async throws -> [Place] {
        Self.places
    }

    func routes(from origin: Coordinate, to destination: Place) async throws -> [RouteOption] {
        let middle = Coordinate(
            latitude: (origin.latitude + destination.coordinate.latitude) / 2 + 0.02,
            longitude: (origin.longitude + destination.coordinate.longitude) / 2
        )
        let end = destination.coordinate
        return [
            RouteOption(id: 0, name: "A5", distance: 38400, travelTime: 2460, path: [origin, end]),
            RouteOption(id: 1, name: "N6", distance: 41200, travelTime: 3300, path: [origin, middle, end])
        ]
    }
}
