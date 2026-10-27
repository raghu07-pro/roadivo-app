import Foundation

/// Searches places and works out driving routes; Apple Maps' services live, scripted in UI tests.
protocol PlaceFinding: Sendable {
    /// Places matching `query`, the closest to `near` first when it's known.
    func places(matching query: String, near: Coordinate?) async throws -> [Place]
    /// Several suggestions for what's typed so far, as Maps' own search lists them.
    func suggestions(matching query: String, near: Coordinate?) async throws -> [PlaceSuggestion]
    /// The place a suggestion is, or nil when Maps can't find it.
    func place(for suggestion: PlaceSuggestion, near: Coordinate?) async throws -> Place?
    /// Driving routes, the fastest first; throws `DirectionsError.noRoute` when there's none.
    func routes(from origin: Coordinate, to destination: Place) async throws -> [RouteOption]
}

/// Finders without suggestions of their own (scripted and test ones) suggest the places they find.
extension PlaceFinding {
    func suggestions(matching query: String, near: Coordinate?) async throws -> [PlaceSuggestion] {
        try await places(matching: query, near: near).map(PlaceSuggestion.init)
    }

    func place(for suggestion: PlaceSuggestion, near: Coordinate?) async throws -> Place? {
        let found = try await places(matching: suggestion.query, near: near)
        return found.first { $0.name == suggestion.title } ?? found.first
    }
}
