import MapKit
import UIKit

/// A still of a route for the card over the other tabs: Apple's muted map with the route drawn on. One picture
/// shared by every tab instead of a live map in each (DECISIONS 146).
@MainActor
final class RouteSnapshot {
    /// Kept until it answers: MapKit stops a snapshot whose snapshotter is let go.
    private var running: MKMapSnapshotter?

    func image(
        of route: RouteOption,
        to destination: Place,
        size: CGSize,
        isDark: Bool,
        line: UIColor
    ) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = Self.region(around: route.path + [destination.coordinate])
        options.size = size
        options.mapType = .mutedStandard
        options.pointOfInterestFilter = .excludingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: isDark ? .dark : .light)
        let snapshotter = MKMapSnapshotter(options: options)
        running = snapshotter
        let path = route.path
        let image: UIImage? = await withCheckedContinuation { continuation in
            snapshotter.start(with: .main) { snapshot, _ in
                continuation.resume(returning: snapshot.map { Self.draw(path, on: $0, line: line) })
            }
        }
        if running === snapshotter {
            running = nil
        }
        return image
    }

    /// Every point in view with a margin, and never closer in than a few streets.
    nonisolated static func region(around points: [Coordinate]) -> MKCoordinateRegion {
        guard let first = points.first else { return MKCoordinateRegion() }
        var south = first.latitude, north = first.latitude, west = first.longitude, east = first.longitude
        for point in points {
            south = min(south, point.latitude)
            north = max(north, point.latitude)
            west = min(west, point.longitude)
            east = max(east, point.longitude)
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (south + north) / 2, longitude: (west + east) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max((north - south) * 1.4, 0.01),
                longitudeDelta: max((east - west) * 1.4, 0.01)
            )
        )
    }

    /// The route over a dark edge, as on the Directions map, with a dot where it ends.
    nonisolated static func draw(
        _ path: [Coordinate],
        on snapshot: MKMapSnapshotter.Snapshot,
        line: UIColor
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = snapshot.image.scale
        return UIGraphicsImageRenderer(size: snapshot.image.size, format: format).image { _ in
            snapshot.image.draw(at: .zero)
            let points = path.map { snapshot.point(for: $0.location) }
            guard let start = points.first, let end = points.last else { return }
            let route = UIBezierPath()
            route.move(to: start)
            points.dropFirst().forEach { route.addLine(to: $0) }
            route.lineCapStyle = .round
            route.lineJoinStyle = .round
            UIColor.black.withAlphaComponent(0.55).setStroke()
            route.lineWidth = 5
            route.stroke()
            line.setStroke()
            route.lineWidth = 3
            route.stroke()
            line.setFill()
            UIBezierPath(arcCenter: end, radius: 4, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()
        }
    }
}
