import MapKit
import SwiftUI

/// Maps: search a place and see the driving routes there from the iPhone, on Apple's map. The search field shows
/// from the search button over the map (DECISIONS 145, 172).
struct DirectionsView: View {
    @Bindable var viewModel: DirectionsViewModel
    /// Show on Car Display, while CarPlay is connected; nil hides it, as videos' Play on Car Display.
    var onShowOnCar: (() -> Void)?
    /// The hour's light for the "Where to?" card's road, which the app works out (`SplashMoment`).
    var sceneTime = RoadScene.TimeOfDay.goldenHour

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    /// The search field has the keyboard: Cancel shows, and the bottom card steps aside.
    @State private var isTyping = false
    /// The route card hidden to one line, so the map has the screen; a new place shows it whole again.
    @State private var isRouteCollapsed = false
    /// The arrow was tapped with the card open: the map follows once the card has folded (`locate`).
    @State private var followsAfterFold = false
    /// The search field shows, opened by the search button (owner, 2026-10-27); Cancel, a place found or leaving it
    /// empty puts the button back.
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                // Each card may take under half the screen, scrolling past that, so the map never closes up.
                let cardHeight = proxy.size.height * 0.45
                ZStack(alignment: .topTrailing) {
                    map
                    if !isSearching {
                        MapButtons(isFollowing: camera.followsUserLocation, onSearch: startSearch, onLocate: locate)
                            .padding(Spacing.md)
                            .transition(.opacity)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if isSearching {
                        searchArea(maxHeight: cardHeight)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomCard(maxHeight: cardHeight) }
            }
            .clearsBottomAccessory()
            .navigationTitle("Maps")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { viewModel.appeared() }
        .task(id: viewModel.query) { await viewModel.findPlaces() }
        .onChange(of: viewModel.location.status) {
            Task { await viewModel.locationChanged() }
        }
        // Frames the trip as soon as a place is chosen, then the whole route once it arrives.
        .onChange(of: viewModel.destination) {
            isRouteCollapsed = false
            withAnimation { camera = .automatic }
        }
        // The route fills the room the card gave up, or leaves it again.
        .onChange(of: isRouteCollapsed) {
            // Following you, or about to, keeps following; otherwise the route fills the room left.
            guard !camera.followsUserLocation, !followsAfterFold else { return }
            withAnimation { camera = .automatic }
        }
        .onChange(of: viewModel.routes) {
            withAnimation { camera = .automatic }
        }
        // A route sent here from the car, or sent away to it.
        .onChange(of: viewModel.screen) {
            withAnimation { camera = .automatic }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("directions.screen")
    }

    private var map: some View {
        RouteMap(viewModel: viewModel, screen: .phone, camera: $camera)
            .mapControls { RouteMap.controls }
            // The compass under the search and location buttons, not behind them.
            .safeAreaPadding(.top, isSearching ? 0 : MapButtons.height(side: 48) + Spacing.md)
            // Touching the map closes the keyboard; panning and pinching still work.
            .simultaneousGesture(TapGesture().onEnded { closeKeyboard() })
            .accessibilityIdentifier("directions.map")
    }

    private func searchArea(maxHeight: CGFloat) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                SearchField(
                    text: $viewModel.query,
                    prompt: "Search for a place",
                    onFocusChange: { focused in
                        withAnimation(.snappy(duration: 0.2)) {
                            isTyping = focused
                            // Left empty, the field steps back for the button.
                            if !focused, viewModel.query.isEmpty {
                                isSearching = false
                            }
                        }
                    },
                    focusesOnAppear: true
                )
                if isTyping {
                    cancelButton
                }
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
            withAnimation(.snappy(duration: 0.2)) { isSearching = false }
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
            } else if viewModel.isShown(on: .phone), let destination = viewModel.destination {
                RouteCard(
                    destination: destination,
                    state: viewModel.routeState,
                    routes: viewModel.routes,
                    selectedRouteID: $viewModel.selectedRouteID,
                    isLocationOff: viewModel.isLocationOff,
                    onRetry: { Task { await viewModel.loadRoutes() } },
                    onClose: { withAnimation { viewModel.clear() } },
                    move: onShowOnCar.map { .init(title: "Show on Car Display", systemImage: "car.fill", action: $0) },
                    isCollapsed: $isRouteCollapsed,
                    onChooseRoute: foldCard
                )
            } else if viewModel.isLocationOff {
                LocationOffNotice()
            } else {
                hint
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    private var hint: some View {
        WhereToCard(time: sceneTime)
            .accessibilityIdentifier("directions.hint")
    }

    /// A route chosen folds the card to its line so the map has the screen, as on the car (owner, 2026-10-27).
    private func foldCard() {
        guard viewModel.isShown(on: .phone) else { return }
        withAnimation(.snappy(duration: 0.25)) { isRouteCollapsed = true }
    }

    /// The arrow: the map follows you, folding an open card first. Only once it has folded: the fold changes the
    /// map's room, which cut MapKit's move short, leaving it off target and no longer following (owner).
    private func locate() {
        guard viewModel.isShown(on: .phone), !isRouteCollapsed else { return follow() }
        followsAfterFold = true
        withAnimation(.snappy(duration: 0.25)) {
            isRouteCollapsed = true
        } completion: {
            followsAfterFold = false
            follow()
        }
    }

    /// Not animated: from a whole route's overview, MapKit's flight down to you outlasted the animation and stopped
    /// part way, off target and no longer following, so the arrow took two taps (owner, 2026-10-27).
    private func follow() {
        camera = .userLocation(fallback: .automatic)
    }

    private func startSearch() {
        withAnimation(.snappy(duration: 0.2)) { isSearching = true }
    }

    /// The keyboard closes, so the map and the route get the whole screen; the field goes once the place is found,
    /// staying to say why when it isn't.
    private func choose(_ suggestion: PlaceSuggestion) {
        closeKeyboard()
        Task {
            await viewModel.choose(suggestion)
            if viewModel.query.isEmpty {
                withAnimation(.snappy(duration: 0.2)) { isSearching = false }
            }
        }
    }

    private func closeKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
