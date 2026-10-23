import Foundation

/// Parked means still for `parkedAfter` seconds in a row; a moving or unknown reading ends it at once, so video stops
/// the moment the car moves (DECISIONS 152). Pure, so it's tested with plain dates.
struct ParkingDetector: Equatable, Sendable {
    /// Long enough that a short stop in traffic doesn't count as parked.
    static let defaultParkedAfter: TimeInterval = 30

    let parkedAfter: TimeInterval
    private(set) var stillSince: Date?

    init(parkedAfter: TimeInterval = Self.defaultParkedAfter) {
        self.parkedAfter = parkedAfter
    }

    mutating func record(_ sample: MotionSample, at time: Date) {
        switch sample {
        case .still:
            if stillSince == nil {
                stillSince = time
            }
        case .moving, .unknown:
            stillSince = nil
        }
    }

    /// Forgets the stop, as when location updates end: not parked until still again for the full time.
    mutating func reset() {
        stillSince = nil
    }

    func isParked(at now: Date) -> Bool {
        guard let stillSince else { return false }
        return now.timeIntervalSince(stillSince) >= parkedAfter
    }

    /// When the car counts as parked if it stays still; nil while it isn't still.
    var parkedAt: Date? {
        stillSince?.addingTimeInterval(parkedAfter)
    }
}
