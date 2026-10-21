import MapKit
import SwiftUI

/// Directions: search a place and see the driving routes there from the iPhone, on Apple's map; Apple Maps does
/// the guidance (DECISIONS 145).
struct DirectionsView: View {
    @Bindable var viewModel: DirectionsViewModel

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    /// The search field has the keyboard: Cancel shows, and the bottom card steps aside.
    @State private var isTyping = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                // Each card may take under half the screen, scrolling past that, so the map never closes up.
                let cardHeight = proxy.size.height * 0.45
                map
                    .safeAreaInset(edge: .top, spacing: 0) { searchArea(maxHeight: cardHeight) }
                    .safeAreaInset(edge: .bottom, spacing: 0) { bottomCard(maxHeight: cardHeight) }
            }
            .clearsBottomAccessory()
            .navigationTitle("Directions")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { viewModel.appeared() }
        .task(id: viewModel.query) { await viewModel.findPlaces() }
        .onChange(of: viewModel.location.status) {
            Task { await viewModel.locationChanged() }
        }
        // Frames the trip as soon as a place is chosen, then the whole route once it arrives.
        .onChange(of: viewModel.destination) {
            withAnimation { camera = .automatic }
        }
        .onChange(of: viewModel.routes) {
            withAnimation { camera = .automatic }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("directions.screen")
    }

    private var map: some View {
        Map(position: $camera) {
            UserAnnotation(anchor: .center) {
                CarMarker()
            }
            ForEach(drawOrder) { option in
                let path = option.path.map(\.location)
                if option.id == viewModel.selectedRoute?.id {
                    // A dark edge under the theme's gradient keeps the route readable on light and dark maps.
                    MapPolyline(coordinates: path)
                        .stroke(Color.roadAsphalt.opacity(0.6), style: Self.line(width: 11))
                    MapPolyline(coordinates: path)
                        .stroke(.roadBrandGradient, style: Self.line(width: 7))
                } else {
                    // The other routes as a dotted lane line, there to pick but not competing.
                    MapPolyline(coordinates: path)
                        .stroke(Color.roadMuted, style: Self.line(width: 5, dash: [1, 10]))
                }
            }
            if let destination = viewModel.destination {
                Annotation(coordinate: destination.coordinate.location, anchor: .bottom) {
                    DestinationMarker()
                } label: {
                    Text(destination.name)
                }
            }
        }
        // Muted streets and no shop or restaurant pins, so Roadivo's route and markers stand out.
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .tint(.roadAccent)
        // Touching the map closes the keyboard; panning and pinching still work.
        .simultaneousGesture(TapGesture().onEnded { closeKeyboard() })
        .accessibilityIdentifier("directions.map")
    }

    private static func line(width: CGFloat, dash: [CGFloat] = []) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash)
    }

    /// The chosen route last, so it's drawn over the others.
    private var drawOrder: [RouteOption] {
        let selected = viewModel.selectedRoute?.id
        return viewModel.routes.filter { $0.id != selected } + viewModel.routes.filter { $0.id == selected }
    }

    private func searchArea(maxHeight: CGFloat) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                SearchField(text: $viewModel.query, prompt: "Search for a place", onFocusChange: { focused in
                    withAnimation(.snappy(duration: 0.2)) { isTyping = focused }
                })
                if isTyping {
                    cancelButton
                }
            }
            // While typing, the results get the room (with the keyboard up, the notice squeezed them to nothing).
            if viewModel.isLocationOff, viewModel.destination == nil, viewModel.query.isEmpty, !isTyping {
                LocationOffNotice()
            }
            HeightLimit(limit: maxHeight) {
                PlaceResults(
                    search: viewModel.search,
                    onChoose: choose,
                    onRetry: { Task { await viewModel.findPlaces() } }
                )
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    /// Leaves the search: clears it and closes the keyboard, back to the map and any route.
    private var cancelButton: some View {
        Button {
            viewModel.query = ""
            closeKeyboard()
        } label: {
            Text("Cancel")
                .font(Typography.cardTitle)
                .foregroundStyle(.roadAccent)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 48)
                .background(.roadSurface, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .accessibilityIdentifier("directions.cancel")
    }

    private func bottomCard(maxHeight: CGFloat) -> some View {
        HeightLimit(limit: maxHeight) {
            if !viewModel.query.isEmpty || isTyping {
                // Searching: the keyboard and the results above have the screen until a place is chosen.
                EmptyView()
            } else if let destination = viewModel.destination {
                RouteCard(
                    destination: destination,
                    state: viewModel.routeState,
                    routes: viewModel.routes,
                    selectedRouteID: $viewModel.selectedRouteID,
                    isLocationOff: viewModel.isLocationOff,
                    onOpenInMaps: { openInMaps(destination) },
                    onRetry: { Task { await viewModel.loadRoutes() } },
                    onClose: { withAnimation { viewModel.clear() } }
                )
            } else if !viewModel.isLocationOff {
                hint
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    private var hint: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Where to?")
                .font(Typography.cardTitle)
                .accessibilityAddTraits(.isHeader)
            Text("Search for a place to see the route from where you are.")
                .font(Typography.secondary)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("directions.hint")
    }

    /// The keyboard closes, so the map and the route get the whole screen.
    private func choose(_ place: Place) {
        closeKeyboard()
        Task { await viewModel.choose(place) }
    }

    private func closeKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Apple Maps gives the spoken, turn-by-turn guidance, keeping the place's name.
    private func openInMaps(_ place: Place) {
        let driving = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        place.mapItem.openInMaps(launchOptions: driving)
    }
}

#Preview("Search") {
    DirectionsView(viewModel: DirectionsViewModel(finder: ScriptedPlaceFinder(), location: ScriptedLocation()))
}

#Preview("Location off, large text") {
    DirectionsView(viewModel: DirectionsViewModel(
        finder: ScriptedPlaceFinder(),
        location: ScriptedLocation(status: .denied)
    ))
    .environment(\.dynamicTypeSize, .accessibility2)
    .preferredColorScheme(.dark)
}
