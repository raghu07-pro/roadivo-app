import MapKit

/// A route on the CarPlay map, drawn as Directions draws it: the chosen route over a dark edge, others dotted.
final class CarPlayRouteLine: MKPolyline {
    enum Style {
        case edge
        case chosen
        case other
    }

    private(set) var style = Style.other

    convenience init(_ path: [Coordinate], style: Style) {
        let points = path.map(\.location)
        self.init(coordinates: points, count: points.count)
        self.style = style
    }
}
