import Foundation

/// Distances as road signs give them: metres then kilometres, or feet then miles, rounded as a driver reads them.
enum RoadDistance {
    static func measurement(meters: Double, usesMiles: Bool) -> Measurement<UnitLength> {
        let meters = max(meters, 0)
        if usesMiles {
            let miles = meters / 1609.344
            guard miles >= 0.1 else {
                return Measurement(value: rounded(meters * 3.28084, toNearest: 50), unit: .feet)
            }
            return Measurement(value: miles < 10 ? tenths(miles) : miles.rounded(), unit: .miles)
        }
        guard meters >= 1000 else {
            return Measurement(value: rounded(meters, toNearest: meters < 100 ? 10 : 50), unit: .meters)
        }
        let kilometers = meters / 1000
        return Measurement(value: kilometers < 10 ? tenths(kilometers) : kilometers.rounded(), unit: .kilometers)
    }

    /// Whether `locale`'s roads are signed in miles, as in the US and the UK.
    static func usesMiles(in locale: Locale) -> Bool {
        locale.measurementSystem != .metric
    }

    private static func rounded(_ value: Double, toNearest step: Double) -> Double {
        (value / step).rounded() * step
    }

    private static func tenths(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
