import Foundation

/// Searches places and works out driving routes; Apple Maps' services live, scripted in UI tests.
protocol PlaceFinding: Sendable {
    /// Places matching `query`, the closest to `near` first when it's known.
    func places(matching query: String, near: Coordinate?) async throws -> [Place]
    /// Driving routes, the fastest first; throws `DirectionsError.noRoute` when there's none.
    func routes(from origin: Coordinate, to destination: Place) async throws -> [RouteOption]
}
