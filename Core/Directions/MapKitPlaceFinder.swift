import MapKit

/// Apple Maps' search and driving directions. Nothing is kept: each search goes to Apple and back.
struct MapKitPlaceFinder: PlaceFinding {
    /// Enough to choose from without a long list over the map.
    static let resultLimit = 8
    /// How far around the iPhone a search prefers, in metres.
    private static let searchRadius: CLLocationDistance = 50000

    func places(matching query: String, near: Coordinate?) async throws -> [Place] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        if let near {
            request.region = MKCoordinateRegion(
                center: near.location,
                latitudinalMeters: Self.searchRadius,
                longitudinalMeters: Self.searchRadius
            )
        }
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.prefix(Self.resultLimit).map(Self.place)
        } catch let error as MKError where error.code == .placemarkNotFound {
            return [] // Maps reports "nothing found" as an error.
        }
    }

    func routes(from origin: Coordinate, to destination: Place) async throws -> [RouteOption] {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.location))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate.location))
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        do {
            let response = try await MKDirections(request: request).calculate()
            return response.routes.enumerated()
                .map { Self.option($0.element, id: $0.offset) }
                .sorted { $0.travelTime < $1.travelTime }
        } catch let error as MKError where error.code == .directionsNotFound {
            throw DirectionsError.noRoute
        }
    }

    private static func place(_ item: MKMapItem) -> Place {
        Place(
            name: item.name ?? item.placemark.title ?? "",
            address: item.placemark.title ?? "",
            coordinate: Coordinate(item.placemark.coordinate)
        )
    }

    private static func option(_ route: MKRoute, id: Int) -> RouteOption {
        let polyline = route.polyline
        var points = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
        polyline.getCoordinates(&points, range: NSRange(location: 0, length: polyline.pointCount))
        return RouteOption(
            id: id,
            name: route.name,
            distance: route.distance,
            travelTime: route.expectedTravelTime,
            path: points.map(Coordinate.init)
        )
    }
}
