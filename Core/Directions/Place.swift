import CoreLocation
import MapKit

/// A point on the map as plain numbers, so places and routes stay simple values across tasks.
struct Coordinate: Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// A place found by the Directions search (DECISIONS 145).
struct Place: Identifiable, Hashable, Sendable {
    let name: String
    /// The street and town, as Apple Maps writes it; empty when Maps has none.
    let address: String
    let coordinate: Coordinate

    var id: String {
        "\(coordinate.latitude),\(coordinate.longitude),\(name)"
    }

    /// For Apple Maps, which keeps the place's name on its directions screen.
    @MainActor
    var mapItem: MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate.location))
        item.name = name
        return item
    }
}

/// One way to drive there.
struct RouteOption: Identifiable, Equatable, Sendable {
    let id: Int
    /// The main road, as Maps names it ("A1"); may be empty.
    let name: String
    /// In metres.
    let distance: Double
    let travelTime: TimeInterval
    let path: [Coordinate]
    /// Turn by turn, for guidance on the CarPlay screen (DECISIONS 147); empty when Maps gave none.
    let steps: [RouteStep]

    init(
        id: Int,
        name: String,
        distance: Double,
        travelTime: TimeInterval,
        path: [Coordinate],
        steps: [RouteStep] = []
    ) {
        self.id = id
        self.name = name
        self.distance = distance
        self.travelTime = travelTime
        self.path = path
        self.steps = steps
    }
}

enum DirectionsError: Error, Equatable {
    case noRoute
}
