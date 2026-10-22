import Foundation
import MapKit
import Testing
@testable import Roadivo

@Suite("Directions")
@MainActor
struct DirectionsViewModelTests {
    private let here = Coordinate(latitude: 38.72, longitude: -9.14)
    private let cabo = Place(
        name: "Cabo da Roca",
        address: "Sintra",
        coordinate: Coordinate(latitude: 38.78, longitude: -9.5)
    )
    private let slow = RouteOption(id: 0, name: "N6", distance: 41200, travelTime: 3300, path: [])
    private let fast = RouteOption(id: 1, name: "A5", distance: 38400, travelTime: 2460, path: [])

    private func model(
        finder: FakePlaceFinder,
        location: FakeLocation? = nil
    ) -> (DirectionsViewModel, FakeLocation) {
        let location = location ?? FakeLocation(status: .allowed, coordinate: here)
        return (DirectionsViewModel(finder: finder, location: location, pause: .zero), location)
    }

    // MARK: Search

    @Test("Typing a place lists what Maps finds, searching near the iPhone")
    func search() async {
        let finder = FakePlaceFinder(places: .success([cabo]))
        let (viewModel, _) = model(finder: finder)
        viewModel.query = "cabo"
        await viewModel.findPlaces()
        #expect(viewModel.search == .found([cabo]))
        #expect(await finder.searches == ["cabo"])
        #expect(await finder.searchedNear == [here])
    }

    @Test("A blank search shows nothing and asks Maps nothing")
    func blankSearch() async {
        let finder = FakePlaceFinder(places: .success([cabo]))
        let (viewModel, _) = model(finder: finder)
        viewModel.query = "   "
        await viewModel.findPlaces()
        #expect(viewModel.search == .idle)
        #expect(await finder.searches.isEmpty)
    }

    @Test("A search with no matches says so")
    func nothingFound() async {
        let (viewModel, _) = model(finder: FakePlaceFinder(places: .success([])))
        viewModel.query = "zzzz"
        await viewModel.findPlaces()
        #expect(viewModel.search == .nothingFound)
    }

    @Test("A search that fails offers to try again")
    func searchFails() async {
        let (viewModel, _) = model(finder: FakePlaceFinder(places: .failure(URLError(.notConnectedToInternet))))
        viewModel.query = "cabo"
        await viewModel.findPlaces()
        #expect(viewModel.search == .failed)
    }

    @Test("A search replaced while it waits never reaches Maps")
    func cancelledSearch() async {
        let finder = FakePlaceFinder(places: .success([cabo]))
        let location = FakeLocation(status: .allowed, coordinate: here)
        let viewModel = DirectionsViewModel(finder: finder, location: location, pause: .seconds(5))
        viewModel.query = "ca"
        let waiting = Task { await viewModel.findPlaces() }
        waiting.cancel()
        await waiting.value
        #expect(viewModel.search == .idle)
        #expect(await finder.searches.isEmpty)
    }

    // MARK: Routes

    @Test("Choosing a place shows its routes from the iPhone, the fastest chosen first")
    func choose() async {
        let finder = FakePlaceFinder(routes: .success([slow, fast]))
        let (viewModel, _) = model(finder: finder)
        viewModel.query = "cabo"
        await viewModel.choose(cabo)
        #expect(viewModel.destination == cabo)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.routeState == .ready)
        #expect(viewModel.routes == [fast, slow])
        #expect(viewModel.selectedRoute == fast)
        #expect(await finder.routedFrom == [here])
    }

    @Test("Picking another route makes it the chosen one")
    func pickRoute() async {
        let (viewModel, _) = model(finder: FakePlaceFinder(routes: .success([slow, fast])))
        await viewModel.choose(cabo)
        viewModel.selectedRouteID = slow.id
        #expect(viewModel.selectedRoute == slow)
    }

    @Test("A place with no driving route says so")
    func noRoute() async {
        let (viewModel, _) = model(finder: FakePlaceFinder(routes: .failure(DirectionsError.noRoute)))
        await viewModel.choose(cabo)
        #expect(viewModel.routeState == .noRoute)
        #expect(viewModel.routes.isEmpty)
    }

    @Test("A route lookup that fails can be tried again")
    func retryRoute() async {
        let finder = FakePlaceFinder(routes: .failure(URLError(.timedOut)))
        let (viewModel, _) = model(finder: finder)
        await viewModel.choose(cabo)
        #expect(viewModel.routeState == .failed)
        await finder.setRoutes(.success([fast]))
        await viewModel.loadRoutes()
        #expect(viewModel.routeState == .ready)
        #expect(viewModel.selectedRoute == fast)
    }

    @Test("Closing the route clears the place and its routes")
    func close() async {
        let (viewModel, _) = model(finder: FakePlaceFinder(routes: .success([fast])))
        await viewModel.choose(cabo)
        viewModel.clear()
        #expect(viewModel.destination == nil)
        #expect(viewModel.routes.isEmpty)
        #expect(viewModel.selectedRoute == nil)
    }

    // MARK: The card over other tabs

    @Test("A found route counts as open, so the other tabs show its card; closing it ends that")
    func activeRoute() async {
        let (viewModel, _) = model(finder: FakePlaceFinder(routes: .success([fast])))
        #expect(!viewModel.hasActiveRoute)
        await viewModel.choose(cabo)
        #expect(viewModel.hasActiveRoute)
        viewModel.clear()
        #expect(!viewModel.hasActiveRoute)
    }

    @Test("A place with no route shows no card")
    func noCardWithoutRoute() async {
        let (viewModel, _) = model(finder: FakePlaceFinder(routes: .failure(DirectionsError.noRoute)))
        await viewModel.choose(cabo)
        #expect(!viewModel.hasActiveRoute)
    }

    @Test("The card's map shows the whole route with room around it")
    func snapshotRegion() {
        let points = [here, Coordinate(latitude: 38.78, longitude: -9.5)]
        let region = RouteSnapshot.region(around: points)
        for point in points {
            #expect(abs(point.latitude - region.center.latitude) < region.span.latitudeDelta / 2)
            #expect(abs(point.longitude - region.center.longitude) < region.span.longitudeDelta / 2)
        }
        let street = RouteSnapshot.region(around: [here])
        #expect(street.span.latitudeDelta >= 0.01)
    }

    // MARK: Location

    @Test("Opening the tab asks for Location")
    func asksOnOpen() {
        let location = FakeLocation(status: .notAsked, coordinate: here)
        let (viewModel, _) = model(finder: FakePlaceFinder(), location: location)
        viewModel.appeared()
        #expect(location.requests == 1)
    }

    @Test("With Location off, choosing a place asks to turn it on instead of routing")
    func locationOff() async {
        let finder = FakePlaceFinder(routes: .success([fast]))
        let (viewModel, _) = model(finder: finder, location: FakeLocation(status: .denied, coordinate: nil))
        await viewModel.choose(cabo)
        #expect(viewModel.isLocationOff)
        #expect(viewModel.routeState == .needsLocation)
        #expect(await finder.routedFrom.isEmpty)
    }

    @Test("Turning Location on in Settings loads the route that was waiting")
    func locationTurnedOn() async {
        let location = FakeLocation(status: .denied, coordinate: nil)
        let (viewModel, _) = model(finder: FakePlaceFinder(routes: .success([fast])), location: location)
        await viewModel.choose(cabo)
        location.status = .allowed
        location.coordinate = here
        await viewModel.locationChanged()
        #expect(viewModel.routeState == .ready)
        #expect(viewModel.selectedRoute == fast)
    }

    // MARK: Text

    @Test("Drive times are in hours and minutes, never under a minute")
    func travelTime() {
        let english = Locale(identifier: "en_US")
        #expect(fast.travelTimeText(locale: english) == "41 min")
        let short = RouteOption(id: 2, name: "", distance: 200, travelTime: 20, path: [])
        #expect(short.travelTimeText(locale: english) == "1 min")
    }

    @Test("Distances use the region's road unit")
    func distance() {
        let german = fast.distanceText(locale: Locale(identifier: "de_DE"))
        #expect(german.contains("38") && german.contains("km"))
        #expect(fast.distanceText(locale: Locale(identifier: "en_US")).contains("mi"))
    }

    @Test("Apple Maps gets the place's name and position")
    func mapItem() {
        let item = cabo.mapItem
        #expect(item.name == "Cabo da Roca")
        #expect(Coordinate(item.placemark.coordinate) == cabo.coordinate)
    }
}

/// Maps' search and routes, answering what each test sets and remembering what it was asked.
private actor FakePlaceFinder: PlaceFinding {
    private var places: Result<[Place], Error>
    private var routes: Result<[RouteOption], Error>
    private(set) var searches: [String] = []
    private(set) var searchedNear: [Coordinate?] = []
    private(set) var routedFrom: [Coordinate] = []

    init(places: Result<[Place], Error> = .success([]), routes: Result<[RouteOption], Error> = .success([])) {
        self.places = places
        self.routes = routes
    }

    func setRoutes(_ routes: Result<[RouteOption], Error>) {
        self.routes = routes
    }

    func places(matching query: String, near: Coordinate?) async throws -> [Place] {
        searches.append(query)
        searchedNear.append(near)
        return try places.get()
    }

    func routes(from origin: Coordinate, to destination: Place) async throws -> [RouteOption] {
        routedFrom.append(origin)
        return try routes.get()
    }
}

@MainActor
private final class FakeLocation: LocationProviding {
    var status: LocationStatus
    var coordinate: Coordinate?
    private(set) var requests = 0

    init(status: LocationStatus, coordinate: Coordinate?) {
        self.status = status
        self.coordinate = coordinate
    }

    var lastCoordinate: Coordinate? {
        status == .allowed ? coordinate : nil
    }

    func requestAccess() {
        requests += 1
    }

    func currentCoordinate() async -> Coordinate? {
        lastCoordinate
    }

    func updates() -> AsyncStream<Coordinate> {
        AsyncStream { $0.finish() }
    }
}
