import Foundation

enum LocationStatus: Equatable, Sendable {
    case notAsked
    case allowed
    case denied
}

/// Where the iPhone is, for routes from here. Only Directions asks, the first time it opens (DECISIONS 145).
@MainActor
protocol LocationProviding: AnyObject {
    var status: LocationStatus { get }
    /// The last place the iPhone was seen, for searching nearby; nil until it's known.
    var lastCoordinate: Coordinate? { get }
    /// Shows iOS's question the first time; does nothing once it's answered.
    func requestAccess()
    /// Asks first if needed, then waits for a fix; nil when Location is off or no fix comes.
    func currentCoordinate() async -> Coordinate?
    /// Fixes as the iPhone moves, for guidance on the CarPlay screen (DECISIONS 147); stops when the task ends.
    func updates() -> AsyncStream<Coordinate>
}
