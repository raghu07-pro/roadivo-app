import Foundation

/// One reading of whether the car is moving, from the iPhone's location (DECISIONS 152).
enum MotionSample: Equatable, Sendable {
    case still
    case moving
    /// No fix, or one too vague to tell; it counts as moving, so video never shows on a guess.
    case unknown

    /// Below this, in m/s (under 2 km/h), the car counts as stopped.
    static let stillSpeed = 0.5
    /// A speed vaguer than this, in m/s, can't tell a stopped car from a crawling one.
    static let maxSpeedError = 2.0

    /// Core Location's speed and its accuracy (negative when unknown), and its own verdict that the iPhone is still.
    static func classify(speed: Double?, speedAccuracy: Double?, isStationary: Bool) -> MotionSample {
        if let speed, speed >= stillSpeed {
            return .moving
        }
        if isStationary {
            return .still
        }
        guard let speed, speed >= 0, let speedAccuracy, speedAccuracy >= 0, speedAccuracy <= maxSpeedError else {
            return .unknown
        }
        return .still
    }
}
