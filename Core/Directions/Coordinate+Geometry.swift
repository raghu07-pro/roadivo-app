import Foundation

/// Street-scale maths for guidance: a flat earth is accurate to centimetres between a route's points.
extension Coordinate {
    private static let earthRadius = 6_371_000.0

    /// Metres east and north of `origin`.
    func offset(from origin: Coordinate) -> (east: Double, north: Double) {
        let radians = Double.pi / 180
        let east = (longitude - origin.longitude) * radians * Self.earthRadius * cos(origin.latitude * radians)
        let north = (latitude - origin.latitude) * radians * Self.earthRadius
        return (east, north)
    }

    /// In metres.
    func distance(to other: Coordinate) -> Double {
        let offset = other.offset(from: self)
        return hypot(offset.east, offset.north)
    }

    /// The compass heading from here to `other`: 0 to 360 degrees, clockwise from north.
    func bearing(to other: Coordinate) -> Double {
        let offset = other.offset(from: self)
        let degrees = atan2(offset.east, offset.north) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }
}
