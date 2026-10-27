#if DEBUG
    import MapKit
    import SwiftUI

    /// The car's Maps tab (owner, 2026-10-27; DECISIONS 172): a place found on the car's search page, from the search
    /// button above the location arrow, and its routes in a card that hides to one line for a bigger map.
    struct CarScreenMapView: View {
        let model: CarScreenModel
        @Bindable var directions: DirectionsViewModel

        @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
        /// The route card hidden to a line along the bottom; a new place shows it whole again.
        @State private var isRouteCollapsed = false
        /// The card's size, so the route is framed beside or above it rather than under it.
        @State private var cardSize = CGSize.zero
        /// The arrow was tapped with the card open: the map follows once the card has folded (`locate`).
        @State private var followsAfterFold = false

        /// The search and location buttons, larger than the iPhone's for a car's screen.
        private static let buttonSide: CGFloat = 56

        var body: some View {
            GeometryReader { proxy in
                RouteMap(viewModel: directions, screen: .car, camera: $camera)
                    .mapControls { RouteMap.controls }
                    // The route in the room the card leaves, and the compass under the buttons.
                    .safeAreaPadding(.top, MapButtons.height(side: Self.buttonSide) + Spacing.sm)
                    .safeAreaPadding(.leading, hasRoute && !isRouteCollapsed ? cardSize.width + Spacing.sm : 0)
                    .safeAreaPadding(.bottom, hasRoute && isRouteCollapsed ? cardSize.height + Spacing.sm : 0)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    // Search above the location arrow, as on the iPhone (owner, 2026-10-27).
                    .overlay(alignment: .topTrailing) {
                        MapButtons(
                            isFollowing: camera.followsUserLocation,
                            side: Self.buttonSide,
                            onSearch: { model.actions?.showPlaceSearch() },
                            onLocate: locate
                        )
                        .padding(Spacing.sm)
                    }
                    .overlay(alignment: .bottomLeading) {
                        card(in: proxy.size)
                            .onGeometryChange(for: CGSize.self) { $0.size } action: { cardSize = $0 }
                            .padding(Spacing.sm)
                    }
            }
            .task { directions.appeared() }
            .onChange(of: directions.location.status) {
                Task { await directions.locationChanged() }
            }
            // Frames the trip as soon as a place is chosen, then the whole route once it arrives, as on the iPhone.
            .onChange(of: directions.destination) {
                isRouteCollapsed = false
                withAnimation { camera = .automatic }
            }
            .onChange(of: directions.routes) {
                withAnimation { camera = .automatic }
            }
            .onChange(of: directions.screen) {
                withAnimation { camera = .automatic }
            }
            // In the trace, so the arrow's follow can be checked on the car's screen.
            .onChange(of: camera.followsUserLocation) {
                CarPlayTrace.write("map follows the car: \(camera.followsUserLocation)")
            }
            .onChange(of: isRouteCollapsed) {
                // Following the car, or about to, keeps following; otherwise the route fills the room left.
                guard !camera.followsUserLocation, !followsAfterFold else { return }
                withAnimation { camera = .automatic }
            }
        }

        private var hasRoute: Bool {
            directions.isShown(on: .car)
        }

        /// A route chosen folds the card to its line so the map has the screen (owner, 2026-10-27).
        private func foldCard() {
            guard hasRoute else { return }
            withAnimation(.snappy(duration: 0.25)) { isRouteCollapsed = true }
        }

        /// The arrow: the map follows the car, folding an open card first. Only once it has folded: the fold changes
        /// the map's room, which cut MapKit's move short, leaving it off target and no longer following (owner).
        private func locate() {
            guard hasRoute, !isRouteCollapsed else { return follow() }
            followsAfterFold = true
            withAnimation(.snappy(duration: 0.25)) {
                isRouteCollapsed = true
            } completion: {
                followsAfterFold = false
                follow()
            }
        }

        /// Not animated: from a whole route's overview, MapKit's flight down to the car outlasted the animation and
        /// stopped part way, off target and no longer following, so the arrow took two taps (owner, 2026-10-27).
        private func follow() {
            CarPlayTrace.write("map arrow: follow (card folded: \(isRouteCollapsed))")
            camera = .userLocation(fallback: .automatic)
        }

        /// Beside the map rather than over most of it, never taller than it; hidden, a line along the bottom.
        @ViewBuilder
        private func card(in size: CGSize) -> some View {
            if hasRoute, let destination = directions.destination {
                HeightLimit(limit: size.height - Spacing.sm * 2) {
                    RouteCard(
                        destination: destination,
                        state: directions.routeState,
                        routes: directions.routes,
                        selectedRouteID: $directions.selectedRouteID,
                        isLocationOff: directions.isLocationOff,
                        onRetry: { Task { await directions.loadRoutes() } },
                        onClose: { withAnimation { directions.clear() } },
                        move: .init(title: "Show on iPhone", systemImage: "iphone") {
                            model.actions?.showRouteOnPhone()
                        },
                        isCollapsed: $isRouteCollapsed,
                        onChooseRoute: foldCard
                    )
                }
                .frame(width: min(isRouteCollapsed ? 400 : 420, size.width * 0.45))
            } else if directions.isLocationOff {
                LocationOffNotice()
                    .frame(width: min(420, size.width * 0.45))
            } else {
                // Nothing chosen: the road at the hour's light asks where to, and a tap searches, as the button does.
                Button {
                    model.actions?.showPlaceSearch()
                } label: {
                    WhereToCard(time: SplashMoment(date: .now).time)
                }
                .buttonStyle(PressableStyle())
                .frame(width: min(420, size.width * 0.45))
            }
        }
    }
#endif
