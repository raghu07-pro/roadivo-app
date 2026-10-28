import CarPlay
import MapKit
import SwiftUI

/// The map in the car's window, under CarPlay's map screen (DECISIONS 147): PlayCarTV's muted map without shop pins,
/// the routes in the theme's colours, the place's flag and the car. Only the map is drawn here, as Apple requires.
final class CarPlayMapViewController: UIViewController {
    private let mapView = MKMapView()
    private let destinationPin = MKPointAnnotation()
    /// How far above the car the camera sits while guiding, in metres: a few streets ahead.
    private static let guidanceDistance: CLLocationDistance = 1500
    /// CarPlay's map buttons float over the map's trailing edge, beyond the safe area.
    private static let mapButtonsWidth: CGFloat = 72

    /// CarPlay's maneuver card: the road's asphalt, dark in both appearances, under white arrows.
    static var guidanceColor: UIColor {
        UIColor(Color.roadAsphalt)
    }

    override func loadView() {
        view = mapView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = configuration
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.isPitchEnabled = false
        followCar()
    }

    /// The routes to choose from, the chosen one on top, framed with the place.
    func show(routes: [RouteOption], selected: RouteOption.ID?, destination: Place?) {
        draw(routes: routes, selected: selected, destination: destination)
        guard !mapView.overlays.isEmpty else { return followCar() }
        mapView.userTrackingMode = .none
        let frame = mapView.overlays.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) }
        let padding = mapView.safeAreaInsets
        mapView.setVisibleMapRect(
            frame,
            edgePadding: UIEdgeInsets(
                top: padding.top + 24,
                left: padding.left + 24,
                bottom: padding.bottom + 24,
                right: padding.right + 24 + Self.mapButtonsWidth
            ),
            animated: true
        )
    }

    /// Guidance: only the route being driven, with the map following the car.
    func guide(along route: RouteOption, to destination: Place) {
        draw(routes: [route], selected: route.id, destination: destination)
        if let car = mapView.userLocation.location?.coordinate {
            mapView.setCamera(
                MKMapCamera(lookingAtCenter: car, fromDistance: Self.guidanceDistance, pitch: 0, heading: 0),
                animated: true
            )
        }
        followCar()
    }

    /// Back to the car after panning, or with nothing else to show.
    func followCar() {
        mapView.setUserTrackingMode(.follow, animated: true)
    }

    func zoom(in zoomsIn: Bool) {
        guard let camera = mapView.camera.copy() as? MKMapCamera else { return }
        camera.centerCoordinateDistance *= zoomsIn ? 0.5 : 2
        mapView.setCamera(camera, animated: true)
    }

    /// A third of the screen per press, as CarPlay's pan arrows expect.
    func pan(_ direction: CPMapTemplate.PanDirection) {
        mapView.userTrackingMode = .none
        let span = mapView.region.span
        var center = mapView.region.center
        if direction.contains(.up) {
            center.latitude = min(center.latitude + span.latitudeDelta / 3, 85)
        }
        if direction.contains(.down) {
            center.latitude = max(center.latitude - span.latitudeDelta / 3, -85)
        }
        if direction.contains(.left) {
            center.longitude -= span.longitudeDelta / 3
        }
        if direction.contains(.right) {
            center.longitude += span.longitudeDelta / 3
        }
        mapView.setCenter(center, animated: true)
    }

    private func draw(routes: [RouteOption], selected: RouteOption.ID?, destination: Place?) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotation(destinationPin)
        guard let destination, !routes.isEmpty else { return }
        for route in routes where route.id != selected {
            mapView.addOverlay(CarPlayRouteLine(route.path, style: .other))
        }
        if let chosen = routes.first(where: { $0.id == selected }) {
            mapView.addOverlay(CarPlayRouteLine(chosen.path, style: .edge))
            mapView.addOverlay(CarPlayRouteLine(chosen.path, style: .chosen))
        }
        destinationPin.coordinate = destination.coordinate.location
        destinationPin.title = destination.name
        mapView.addAnnotation(destinationPin)
    }
}

extension CarPlayMapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
        guard let line = overlay as? CarPlayRouteLine else { return MKOverlayRenderer(overlay: overlay) }
        let renderer = MKPolylineRenderer(polyline: line)
        renderer.lineCap = .round
        renderer.lineJoin = .round
        switch line.style {
        case .edge:
            renderer.strokeColor = UIColor(Color.roadAsphalt).withAlphaComponent(0.6)
            renderer.lineWidth = 11
        case .chosen:
            renderer.strokeColor = UIColor(Color.roadBrand)
            renderer.lineWidth = 7
        case .other:
            renderer.strokeColor = UIColor(Color.roadMuted)
            renderer.lineWidth = 5
            renderer.lineDashPattern = [1, 10]
        }
        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        guard annotation === destinationPin else { return nil }
        let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "destination")
        view.glyphImage = UIImage(systemName: "flag.checkered")
        view.markerTintColor = UIColor(Color.roadBrand)
        return view
    }
}
