import MapKit
import SwiftUI

/// Apple's map with where the iPhone is, the chosen place and its routes, for Maps on the iPhone and in the car
/// (DECISIONS 145, 172). Full-size maps add `RouteMap.controls`; the car's small one has none.
struct RouteMap: View {
    let viewModel: DirectionsViewModel
    /// The screen it's on: the route shows only on the screen that has it (DECISIONS 172).
    let screen: PlaybackOrigin
    @Binding var camera: MapCameraPosition

    var body: some View {
        Map(position: $camera) {
            UserAnnotation(anchor: .center) {
                CarMarker()
            }
            ForEach(drawOrder) { option in
                let path = option.path.map(\.location)
                if option.id == viewModel.selectedRoute?.id {
                    // Drawn as PlayCarTV's road: asphalt edged in the theme's golden light, with the yellow centre line
                    // of the app's road scenes, readable on light and dark maps (DECISIONS 172).
                    MapPolyline(coordinates: path)
                        .stroke(.roadBrandGradient, style: Self.line(width: 15))
                    MapPolyline(coordinates: path)
                        .stroke(Color.roadAsphalt, style: Self.line(width: 10))
                    MapPolyline(coordinates: path)
                        .stroke(Palette.laneYellow, style: Self.line(width: 2, cap: .butt, dash: [6, 8]))
                } else {
                    // The other routes as a dotted lane line, there to pick but not competing.
                    MapPolyline(coordinates: path)
                        .stroke(Color.roadMuted, style: Self.line(width: 5, dash: [1, 10]))
                }
            }
            if viewModel.isShown(on: screen), let destination = viewModel.destination {
                Annotation(coordinate: destination.coordinate.location, anchor: .bottom) {
                    DestinationMarker()
                } label: {
                    Text(destination.name)
                }
            }
        }
        // Muted streets and no shop or restaurant pins, so PlayCarTV's route and markers stand out.
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .tint(.roadAccent)
    }

    /// North and the scale, for a map big enough to use them; where you are is `MapButtons`' arrow.
    @ViewBuilder
    static var controls: some View {
        MapCompass()
        MapScaleView()
    }

    private static func line(width: CGFloat, cap: CGLineCap = .round, dash: [CGFloat] = []) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: cap, lineJoin: .round, dash: dash)
    }

    /// The chosen route last, so it's drawn over the others.
    private var drawOrder: [RouteOption] {
        guard viewModel.isShown(on: screen) else { return [] }
        let selected = viewModel.selectedRoute?.id
        return viewModel.routes.filter { $0.id != selected } + viewModel.routes.filter { $0.id == selected }
    }
}
