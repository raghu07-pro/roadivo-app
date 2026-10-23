import CarPlay
import MapKit
import OSLog

/// Roadivo's CarPlay navigation app, when `ROADIVO_CARPLAY_APP` is `map` (DECISIONS 147, 152): Apple's map screen
/// over Roadivo's map, a search for places, Directions' routes as a trip to choose from, then turn-by-turn guidance.
final class CarPlayNavigationSceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPMapTemplateDelegate {
    private var interfaceController: CPInterfaceController?
    private var carWindow: CPWindow?
    private let map = CarPlayMapViewController()
    private let mapTemplate = CPMapTemplate()
    /// Kept while its screen is open: the search template holds its delegate weakly.
    private var search: CarPlayPlaceSearch?
    private var guidance: CarPlayGuidance?
    private var isWatching = false
    /// The place and routes offered as a trip, so picking a route doesn't redraw CarPlay's trip card.
    private var previewKey: String?
    /// The place and outcome last reported in an alert, so each problem is told once.
    private var alertKey: String?
    private let logger = Logger(subsystem: "com.roadivo", category: "CarPlay")

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        MainActor.assumeIsolated {
            CarPlayTrace.write("navigation connect, iOS \(UIDevice.current.systemVersion)")
            self.interfaceController = interfaceController
            carWindow = window
            window.rootViewController = map
            AppEnvironment.current?.carConnection.isCarPlayConnected = true
            AppEnvironment.current?.location.requestAccess()
            mapTemplate.mapDelegate = self
            mapTemplate.guidanceBackgroundColor = CarPlayMapViewController.guidanceColor
            mapTemplate.mapButtons = mapButtons()
            showBrowseButtons()
            interfaceController.setRootTemplate(mapTemplate, animated: false) { [logger] success, error in
                if let error {
                    logger.error("Map template: \(error.localizedDescription, privacy: .public)")
                }
                CarPlayTrace.write("map accepted: \(success)")
            }
            previewKey = nil
            showRoutes()
            if !isWatching {
                watchDirections()
            }
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        MainActor.assumeIsolated {
            CarPlayTrace.write("navigation disconnect")
            guidance?.stop()
            guidance = nil
            search = nil
            AppEnvironment.current?.carConnection.isCarPlayConnected = false
            window.rootViewController = nil
            carWindow = nil
            self.interfaceController = nil
        }
    }

    // MARK: Map template

    func mapTemplate(_ mapTemplate: CPMapTemplate, selectedPreviewFor trip: CPTrip, using routeChoice: CPRouteChoice) {
        MainActor.assumeIsolated {
            AppEnvironment.current?.directions.selectedRouteID = routeChoice.userInfo as? Int
        }
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice) {
        MainActor.assumeIsolated { startGuidance(trip, choice: routeChoice) }
    }

    /// CarPlay ended guidance itself, as when another app starts navigating.
    func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
        MainActor.assumeIsolated { guidanceEnded() }
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection) {
        MainActor.assumeIsolated { map.pan(direction) }
    }

    // MARK: Routes

    /// Redraws when the iPhone's Directions or the car's search picks a place or a route.
    @MainActor
    private func watchDirections() {
        guard let directions = AppEnvironment.current?.directions else { return }
        isWatching = true
        withObservationTracking {
            _ = directions.destination
            _ = directions.routes
            _ = directions.selectedRouteID
            _ = directions.routeState
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.directionsChanged() }
        }
    }

    @MainActor
    private func directionsChanged() {
        isWatching = false
        guard interfaceController != nil else { return }
        showRoutes()
        watchDirections()
    }

    /// Directions' routes to its place as a trip to choose from, or the map following the car.
    @MainActor
    private func showRoutes() {
        guard guidance == nil, let directions = AppEnvironment.current?.directions else { return }
        guard let destination = directions.destination else {
            previewKey = nil
            mapTemplate.hideTripPreviews()
            map.show(routes: [], selected: nil, destination: nil)
            return
        }
        reportProblem(directions.routeState, for: destination)
        guard directions.hasActiveRoute else { return }
        let key = "\(destination.id)|\(directions.routes.map(\.id))"
        if key != previewKey {
            previewKey = key
            mapTemplate.showTripPreviews(
                [Self.trip(to: destination, routes: directions.routes)],
                textConfiguration: CPTripPreviewTextConfiguration(
                    startButtonTitle: String(appLocalized: "Go"),
                    additionalRoutesButtonTitle: String(appLocalized: "More Routes"),
                    overviewButtonTitle: String(appLocalized: "Overview")
                )
            )
        }
        map.show(routes: directions.routes, selected: directions.selectedRoute?.id, destination: destination)
    }

    @MainActor
    private static func trip(to destination: Place, routes: [RouteOption]) -> CPTrip {
        let locale = AppLocale.current
        let choices = routes.map { route in
            let summary = String(
                appLocalized: "\(route.travelTimeText(locale: locale)) · \(route.distanceText(locale: locale))"
            )
            let choice = CPRouteChoice(
                summaryVariants: route.name.isEmpty ? [summary] : [String(appLocalized: "via \(route.name)")],
                additionalInformationVariants: [summary],
                selectionSummaryVariants: [summary]
            )
            choice.userInfo = route.id
            return choice
        }
        return CPTrip(origin: MKMapItem.forCurrentLocation(), destination: destination.mapItem, routeChoices: choices)
    }

    /// Says once why a place has no routes: Location is off, Maps has no route, or the network failed.
    @MainActor
    private func reportProblem(_ state: DirectionsViewModel.RouteState, for destination: Place) {
        let message: String
        switch state {
        case .needsLocation:
            message = String(appLocalized: "Turn on Location in Settings to see routes from where you are.")
        case .noRoute:
            message = String(appLocalized: "No driving route found to this place.")
        case .failed:
            message = String(appLocalized: "Couldn't find a route. Check your connection and try again.")
        case .loading, .ready:
            alertKey = nil
            return
        }
        let key = "\(destination.id)|\(state)"
        guard key != alertKey, let interfaceController, interfaceController.presentedTemplate == nil else { return }
        alertKey = key
        let alert = CPAlertTemplate(
            titleVariants: [message],
            actions: [
                CPAlertAction(title: String(appLocalized: "OK"), style: .default) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                    }
                }
            ]
        )
        interfaceController.presentTemplate(alert, animated: true, completion: nil)
    }

    // MARK: Guidance

    @MainActor
    private func startGuidance(_ trip: CPTrip, choice: CPRouteChoice) {
        guard let environment = AppEnvironment.current,
              let destination = environment.directions.destination,
              let route = environment.directions.routes.first(where: { $0.id == choice.userInfo as? Int })
              ?? environment.directions.selectedRoute
        else { return }
        CarPlayTrace.write("guidance started, \(route.steps.count) steps")
        mapTemplate.hideTripPreviews()
        let guidance = CarPlayGuidance(
            session: mapTemplate.startNavigationSession(for: trip),
            mapTemplate: mapTemplate,
            route: route,
            destination: destination,
            environment: environment,
            map: map
        ) { [weak self] in
            // Arrived: the trip is done on the iPhone as well.
            AppEnvironment.current?.directions.clear()
            self?.guidanceEnded()
        }
        self.guidance = guidance
        mapTemplate.trailingNavigationBarButtons = [
            CPBarButton(title: String(appLocalized: "End Route")) { [weak self] _ in
                MainActor.assumeIsolated { self?.endGuidance() }
            }
        ]
        guidance.start()
    }

    /// The driver's End Route: the route stays offered, to start again.
    @MainActor
    private func endGuidance() {
        guidance?.cancel()
        guidanceEnded()
    }

    @MainActor
    private func guidanceEnded() {
        CarPlayTrace.write("guidance ended")
        guidance?.stop()
        guidance = nil
        previewKey = nil
        showBrowseButtons()
        showRoutes()
    }

    // MARK: Buttons

    @MainActor
    private func showBrowseButtons() {
        let search = CPBarButton(image: UIImage(systemName: "magnifyingglass") ?? UIImage()) { [weak self] _ in
            MainActor.assumeIsolated { self?.showSearch() }
        }
        mapTemplate.trailingNavigationBarButtons = [search]
    }

    @MainActor
    private func showSearch() {
        guard let environment = AppEnvironment.current else { return }
        let search = CarPlayPlaceSearch(environment: environment) { [weak self] in
            self?.interfaceController?.popToRootTemplate(animated: true, completion: nil)
        }
        self.search = search
        interfaceController?.pushTemplate(search.template, animated: true, completion: nil)
    }

    /// Zoom, pan and back to the car: CarPlay's four map buttons at most.
    @MainActor
    private func mapButtons() -> [CPMapButton] {
        let zoomIn = CPMapButton { [weak self] _ in MainActor.assumeIsolated { self?.map.zoom(in: true) } }
        zoomIn.image = UIImage(systemName: "plus.magnifyingglass")
        let zoomOut = CPMapButton { [weak self] _ in MainActor.assumeIsolated { self?.map.zoom(in: false) } }
        zoomOut.image = UIImage(systemName: "minus.magnifyingglass")
        let pan = CPMapButton { [weak self] _ in
            MainActor.assumeIsolated { self?.mapTemplate.showPanningInterface(animated: true) }
        }
        pan.image = UIImage(systemName: "arrow.up.and.down.and.arrow.left.and.right")
        let car = CPMapButton { [weak self] _ in MainActor.assumeIsolated { self?.map.followCar() } }
        car.image = UIImage(systemName: "location.fill")
        return [zoomIn, zoomOut, pan, car]
    }
}
