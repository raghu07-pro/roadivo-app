import Foundation
import Testing
@testable import PlayCarTV

@Suite("Road distance")
struct RoadDistanceTests {
    @Test(
        "Metric: tens of metres, then fifties, then kilometres to a tenth below 10 km",
        arguments: [
            (87.0, 90.0, UnitLength.meters),
            (437, 450, .meters),
            (1234, 1.2, .kilometers),
            (15678, 16, .kilometers),
            (-5, 0, .meters)
        ]
    )
    func metric(meters: Double, value: Double, unit: UnitLength) {
        let distance = RoadDistance.measurement(meters: meters, usesMiles: false)
        #expect(distance.value == value)
        #expect(distance.unit == unit)
    }

    @Test(
        "Miles: feet by fifties under a tenth of a mile, then miles to a tenth below 10",
        arguments: [
            (50.0, 150.0, UnitLength.feet),
            (3774, 2.3, .miles),
            (20278, 13, .miles)
        ]
    )
    func miles(meters: Double, value: Double, unit: UnitLength) {
        let distance = RoadDistance.measurement(meters: meters, usesMiles: true)
        #expect(distance.value == value)
        #expect(distance.unit == unit)
    }

    @Test("Roads are signed in miles in the US and the UK, in kilometres elsewhere")
    func milesByRegion() {
        #expect(RoadDistance.usesMiles(in: Locale(identifier: "en_US")))
        #expect(RoadDistance.usesMiles(in: Locale(identifier: "en_GB")))
        #expect(!RoadDistance.usesMiles(in: Locale(identifier: "pt_PT")))
        #expect(!RoadDistance.usesMiles(in: Locale(identifier: "hi_IN")))
    }
}
