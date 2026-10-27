import Foundation
import Observation
import UIKit

/// The Directions tab: search a place, then see the driving routes there from the iPhone's location
/// (DECISIONS 145). Guidance itself is Apple Maps' job.
@MainActor
@Observable
final class DirectionsViewModel {
    enum Search: Equatable {
        case idle
        case searching
        case found([PlaceSuggestion])
        case nothingFound
        case failed
    }

    enum RouteState: Equatable {
        case loading
        case ready
        case noRoute
        case failed
        /// Location is off, so there's no start for a route.
        case needsLocation
    }

    var query = ""
    private(set) var search: Search = .idle
    private(set) var destination: Place?
    private(set) var routeState: RouteState = .loading
    private(set) var routes: [RouteOption] = []
    var selectedRouteID: RouteOption.ID?
    /// The screen showing the route, as a video's `PlaybackOrigin`: the one it was chosen on, until it's moved
    /// (owner, 2026-10-27; DECISIONS 172). The other screen's Maps shows no route.
    private(set) var screen = PlaybackOrigin.phone
    let location: LocationProviding

    private let finder: PlaceFinding
    /// Typing pauses this long before a search, so each letter doesn't send one.
    private let pause: Duration
    /// The route's still for the card over the other tabs, and which route and look it shows.
    private(set) var snapshot: UIImage?
    @ObservationIgnored private var snapshotKey: String?
    @ObservationIgnored private let snapshotter = RouteSnapshot()

    init(finder: PlaceFinding, location: LocationProviding, pause: Duration = .milliseconds(350)) {
        self.finder = finder
        self.location = location
        self.pause = pause
    }

    var selectedRoute: RouteOption? {
        routes.first { $0.id == selectedRouteID } ?? routes.first
    }

    var isLocationOff: Bool {
        location.status == .denied
    }

    /// A route is open and found: the other tabs show it in a small card (DECISIONS 146).
    var hasActiveRoute: Bool {
        destination != nil && routeState == .ready && selectedRoute != nil
    }

    /// The route is open on `screen`: its map, card and the small window over the other tabs show it there.
    func isShown(on screen: PlaybackOrigin) -> Bool {
        destination != nil && self.screen == screen
    }

    /// Show on iPhone / Show on Car Display, as Play on iPhone / Play on Car Display move a video.
    func move(to screen: PlaybackOrigin) {
        self.screen = screen
    }

    /// Makes the still once per route, look and size; every tab's card shares it.
    func makeSnapshot(size: CGSize, isDark: Bool, line: UIColor) async {
        guard let destination, let route = selectedRoute else { return }
        let key = "\(destination.id)|\(route.id)|\(isDark)|\(Int(size.width))x\(Int(size.height))"
        guard key != snapshotKey else { return }
        snapshotKey = key
        let image = await snapshotter.image(of: route, to: destination, size: size, isDark: isDark, line: line)
        if snapshotKey == key {
            snapshot = image
        }
    }

    /// iOS asks for Location the first time the tab opens, not at launch.
    func appeared() {
        location.requestAccess()
    }

    /// Run for each change of `query`; a newer change cancels it during the pause.
    func findPlaces() async {
        await lookUp(query) { search = $0 }
    }

    /// Searches `text` after the typing pause, reporting each step; the car's Maps tab runs its own, so typing there
    /// leaves the iPhone's field alone (DECISIONS 172).
    func lookUp(_ text: String, report: (Search) -> Void) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return report(.idle)
        }
        do {
            try await Task.sleep(for: pause)
        } catch {
            return // A newer query replaced this one.
        }
        report(.searching)
        do {
            let found = try await finder.suggestions(matching: text, near: location.lastCoordinate)
            guard !Task.isCancelled else { return }
            report(found.isEmpty ? .nothingFound : .found(found))
        } catch {
            guard !Task.isCancelled else { return }
            report(.failed)
        }
    }

    /// A suggestion from the list: found on the map, then its routes, as `choose(_ place:)`.
    func choose(_ suggestion: PlaceSuggestion) async {
        await choose(suggestion) { search = $0 }
    }

    /// The same for the car's own search, whose list `report` keeps: searching while it's found, idle once it is.
    func choose(_ suggestion: PlaceSuggestion, on screen: PlaybackOrigin = .phone, report: (Search) -> Void) async {
        report(.searching)
        do {
            guard let place = try await finder.place(for: suggestion, near: location.lastCoordinate) else {
                return report(.nothingFound)
            }
            report(.idle)
            await choose(place, on: screen)
        } catch {
            report(.failed)
        }
    }

    func choose(_ place: Place, on screen: PlaybackOrigin = .phone) async {
        self.screen = screen
        destination = place
        query = ""
        search = .idle
        await loadRoutes()
    }

    func loadRoutes() async {
        guard let destination else { return }
        routes = []
        selectedRouteID = nil
        routeState = .loading
        guard let origin = await location.currentCoordinate() else {
            if self.destination == destination {
                routeState = .needsLocation
            }
            return
        }
        let state: RouteState
        var found: [RouteOption] = []
        do {
            found = try await finder.routes(from: origin, to: destination)
            state = found.isEmpty ? .noRoute : .ready
        } catch DirectionsError.noRoute {
            state = .noRoute
        } catch {
            state = .failed
        }
        // Closed, or another place chosen, while this one was loading.
        guard self.destination == destination else { return }
        routes = found.sorted { $0.travelTime < $1.travelTime }
        selectedRouteID = routes.first?.id
        routeState = state
    }

    /// Location was turned on in Settings while a route waited for it.
    func locationChanged() async {
        if routeState == .needsLocation, location.status == .allowed {
            await loadRoutes()
        }
    }

    func clear() {
        destination = nil
        routes = []
        selectedRouteID = nil
        routeState = .loading
        snapshot = nil
        snapshotKey = nil
    }
}
