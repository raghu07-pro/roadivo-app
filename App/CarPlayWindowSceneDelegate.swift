import CarPlay
import OSLog

/// Roadivo's own CarPlay window when `ROADIVO_CARPLAY_APP` is `window` (DECISIONS 152–154): no map; the four tabs as
/// buttons along the top, the chosen video while parked, a drag to move its place, and Close to stop it.
final class CarPlayWindowSceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate,
    CPSessionConfigurationDelegate, CPMapTemplateDelegate {
    private var interfaceController: CPInterfaceController?
    /// Tells when the car limits its keyboard, as it does while moving: the car's own word on parked (DECISIONS 153).
    private var session: CPSessionConfiguration?
    private let screen = CarPlayWindowController()
    private let root = CPMapTemplate()
    private let artwork = CarPlayArtwork()
    private var carBrowser: CarBrowserController?
    private var browserControls: CarBrowserControls?
    private var lists: Lists?
    private var isWatching = false
    /// What the window and buttons last showed, so the buttons are only rebuilt when that changes.
    private var shownState: CarWindowState?
    private var shownPlaying: Bool?
    private var shownLive: Bool?
    private let logger = Logger(subsystem: "com.roadivo", category: "CarPlay")

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        MainActor.assumeIsolated {
            CarPlayTrace.write("window connect, iOS \(UIDevice.current.systemVersion)")
            self.interfaceController = interfaceController
            if CarPlayAvailability.hasExperimentalBrowser, carBrowser == nil {
                let browser = CarBrowserController()
                carBrowser = browser
                screen.installBrowser(browser)
                browser.onChange = { [weak self] in self?.browserControls?.refresh() }
            }
            window.rootViewController = screen
            screen.avoidMapButtons(window.mapButtonSafeAreaLayoutGuide)
            root.mapDelegate = self
            AppEnvironment.current?.carConnection.isCarPlayConnected = true
            AppEnvironment.current?.parking.start()
            let session = CPSessionConfiguration(delegate: self)
            self.session = session
            carLimitsChanged(session.limitedUserInterfaces)
            lists = makeLists(interfaceController)
            if let carBrowser {
                let controls = CarBrowserControls(browser: carBrowser, root: root, interface: interfaceController)
                controls.onSearch = { [weak self] in self?.lists?.browser.showSearch() }
                controls.onSiteSearch = { [weak self] url in self?.lists?.browser.showSearch(on: url) }
                controls.onHome = { [weak self] in self?.showBrowserStartPage() }
                controls.onClose = { [weak self] in self?.closeBrowser() }
                controls.onOpen = { [weak self] url in self?.openBrowser(url) }
                browserControls = controls
            }
            shownState = nil
            shownPlaying = nil
            shownLive = nil
            refresh()
            interfaceController.setRootTemplate(root, animated: false) { [logger] success, error in
                if let error {
                    logger.error("Window root: \(error.localizedDescription, privacy: .public)")
                }
                CarPlayTrace.write("window root accepted: \(success)")
            }
            if !isWatching {
                watch()
            }
            // The Browser tab's icons, when Discover hasn't fetched them yet.
            Task { await AppEnvironment.current?.siteIcons.refresh(BrowserSite.all) }
            #if DEBUG
                // Temporary, while car playback won't start: picks the first item as a tap on the car would.
                if ProcessInfo.processInfo.arguments.contains("-car-autoplay") {
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .seconds(3)) // Long enough for the library and Pro to load.
                        self?.autoplayFirstItem()
                    }
                }
            #endif
        }
    }

    #if DEBUG
        @MainActor
        private func autoplayFirstItem() {
            guard let environment = AppEnvironment.current else { return }
            let menu = CarPlayMenu.build(from: environment.repository)
            let queue = menu.recent.isEmpty ? menu.groups.first?.items ?? [] : menu.recent
            guard let first = queue.first else {
                return CarPlayTrace.write("autoplay: nothing in the library")
            }
            CarPlayTrace.write("autoplay: \(first.title)")
            environment.playback.play(first, queue: queue, from: .car)
            backToWindow()
        }
    #endif

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        MainActor.assumeIsolated {
            CarPlayTrace.write("window disconnect")
            AppEnvironment.current?.parking.stop()
            carBrowser?.close()
            browserControls = nil
            screen.stopUpdating()
            AppEnvironment.current?.carConnection.isCarPlayConnected = false
            window.rootViewController = nil
            self.interfaceController = nil
            session = nil
            lists = nil
        }
    }

    /// CarPlay calls this on the main thread, though Apple's protocol doesn't say so.
    nonisolated func sessionConfiguration(
        _ sessionConfiguration: CPSessionConfiguration,
        limitedUserInterfacesChanged limitedUserInterfaces: CPLimitableUserInterface
    ) {
        MainActor.assumeIsolated { carLimitsChanged(limitedUserInterfaces) }
    }

    /// An unlocked keyboard is how the car says it isn't moving; `ParkingMonitor` still checks Location.
    @MainActor
    private func carLimitsChanged(_ limits: CPLimitableUserInterface) {
        let isUnlimited = !limits.contains(.keyboard)
        CarPlayTrace.write("car limits keyboard: \(!isUnlimited), lists: \(limits.contains(.lists))")
        AppEnvironment.current?.parking.carAllowsFullInterface = isUnlimited
    }

    // MARK: Updates

    /// Redraws when Pro, what's playing, the parked state, Location, the library or the Browser's sites change.
    @MainActor
    private func watch() {
        guard let environment = AppEnvironment.current else { return }
        isWatching = true
        withObservationTracking {
            _ = environment.proAccess.isPro
            _ = environment.playback.current
            _ = environment.playback.origin
            _ = environment.playback.isPlaying
            _ = environment.playback.isLive
            _ = environment.playback.queue.count
            _ = environment.playback.videoGravity
            _ = environment.parking.isParked
            _ = environment.parking.isLocationDenied
            _ = environment.router.libraryRevision
            _ = environment.siteIcons.icons
            _ = environment.browser.foundVideo
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.changed() }
        }
    }

    @MainActor
    private func changed() {
        isWatching = false
        guard interfaceController != nil else { return }
        refresh()
        watch()
    }

    @MainActor
    private func refresh() {
        guard let environment = AppEnvironment.current else { return }
        let playback = environment.playback
        let state = CarWindowState.make(
            isPro: environment.proAccess.isPro,
            // Only what was picked on the car; the iPhone's own video stays on the iPhone (DECISIONS 155).
            isPlaying: playback.isActive && playback.origin == .car,
            isParked: environment.parking.isParked,
            isLocationDenied: environment.parking.isLocationDenied
        )
        screen.show(state, playback: playback)
        screen.showBrowser(carBrowser?.isOpen == true)
        if let browser = carBrowser, browser.isOpen {
            browser.setAllowed(CarBrowserAccess.isAllowed(isPro: environment.proAccess.isPro))
            browserControls?.refresh()
            shownState = nil
            return
        }
        if state != shownState {
            let parking = environment.parking
            CarPlayTrace.write("""
            window shows \(state), parked: \(parking.isParked), car unlimited: \(parking.carAllowsFullInterface), \
            last reading: \(parking.lastSample.map { "\($0)" } ?? "none")
            """)
            if !state.showsTabs {
                backToWindow() // Something started, here or on the iPhone: the window shows it.
            }
            showBarButtons(for: state)
        }
        if state != shownState || playback.isPlaying != shownPlaying || playback.isLive != shownLive {
            root.mapButtons = state.showsTabs || state == .upgrade
                ? []
                : playbackButtons(isPlaying: playback.isPlaying, isLive: playback.isLive)
        }
        shownState = state
        shownPlaying = playback.isPlaying
        shownLive = playback.isLive
        fillLists(environment)
    }

    // MARK: Buttons

    /// The tabs while nothing plays; while something plays, previous and next, and Close; the bar hides itself over
    /// the video.
    @MainActor
    private func showBarButtons(for state: CarWindowState) {
        switch state {
        case .upgrade:
            root.leadingNavigationBarButtons = []
            root.trailingNavigationBarButtons = []
        case .home:
            root.leadingNavigationBarButtons = [tabButton(.favorites), tabButton(.recent)]
            root.trailingNavigationBarButtons = [tabButton(.library), tabButton(.browser)]
        case .video, .driving, .needsLocation:
            let close = CPBarButton(title: String(appLocalized: "Close")) { _ in
                MainActor.assumeIsolated { AppEnvironment.current?.playback.stop() }
            }
            root.leadingNavigationBarButtons = [
                barButton("backward.end.fill") { $0.previous() },
                barButton("forward.end.fill") { $0.next() }
            ]
            root.trailingNavigationBarButtons = [close]
        }
        root.automaticallyHidesNavigationBar = state == .video
        root.hidesButtonsWithNavigationBar = state == .video
    }

    @MainActor
    private func tabButton(_ tab: Tab) -> CPBarButton {
        CPBarButton(title: tab.title) { [weak self] _ in
            MainActor.assumeIsolated { self?.open(tab) }
        }
    }

    /// Back 15 seconds, play or pause, and forward 15 seconds down the window's edge, as in Car Mode; a live stream,
    /// which can't move, gets play or pause alone. The steering wheel's buttons work too.
    @MainActor
    private func playbackButtons(isPlaying: Bool, isLive: Bool) -> [CPMapButton] {
        let playPause = playbackButton(isPlaying ? "pause.fill" : "play.fill") { $0.togglePlayPause() }
        guard !isLive else { return [playPause] }
        return [
            playbackButton("gobackward.15") { $0.skip(by: -15) },
            playPause,
            playbackButton("goforward.15") { $0.skip(by: 15) }
        ]
    }

    @MainActor
    private func playbackButton(_ symbol: String, action: @escaping (PlaybackController) -> Void) -> CPMapButton {
        let button = CPMapButton { _ in
            MainActor.assumeIsolated { Self.perform(action) }
        }
        button.image = UIImage(systemName: symbol)
        return button
    }

    @MainActor
    private func barButton(_ symbol: String, action: @escaping (PlaybackController) -> Void) -> CPBarButton {
        CPBarButton(image: UIImage(systemName: symbol) ?? UIImage()) { _ in
            MainActor.assumeIsolated { Self.perform(action) }
        }
    }

    @MainActor
    private static func perform(_ action: (PlaybackController) -> Void) {
        if let playback = AppEnvironment.current?.playback {
            action(playback)
        }
    }

    // MARK: Lists

    private enum Tab {
        case favorites
        case recent
        case library
        case browser

        var title: String {
            switch self {
            case .favorites: String(appLocalized: "Favorites")
            case .recent: String(appLocalized: "Recent")
            case .library: String(appLocalized: "Library")
            case .browser: String(appLocalized: "Browser")
            }
        }
    }

    private struct Lists {
        let favorites: CPListTemplate
        let recent: CPListTemplate
        let library: CPListTemplate
        let browser: CarPlayBrowserTab
    }

    @MainActor
    private func makeLists(_ interfaceController: CPInterfaceController) -> Lists {
        let favorites = CPListTemplate(title: Tab.favorites.title, sections: [])
        let recent = CPListTemplate(title: Tab.recent.title, sections: [])
        let library = CPListTemplate(title: Tab.library.title, sections: [])
        for list in [favorites, recent] {
            list.emptyViewTitleVariants = [String(appLocalized: "Nothing here yet")]
        }
        library.emptyViewTitleVariants = [String(appLocalized: "Add a source on your iPhone")]
        // The page's video plays in this window, so its row presents itself, then the window comes back.
        let browser = CarPlayBrowserTab(
            interfaceController: interfaceController,
            markAsVideo: { _ in true },
            onPlay: { [weak self] in self?.backToWindow() },
            openPage: carBrowser == nil ? nil : { [weak self] url in self?.openBrowser(url) }
        )
        return Lists(favorites: favorites, recent: recent, library: library, browser: browser)
    }

    @MainActor
    private func open(_ tab: Tab) {
        guard let lists, let interfaceController else { return }
        let template: CPTemplate = switch tab {
        case .favorites: lists.favorites
        case .recent: lists.recent
        case .library: lists.library
        case .browser: lists.browser.template
        }
        interfaceController.pushTemplate(template, animated: true) { [logger] _, error in
            if let error {
                logger.error("Open \(template.description, privacy: .public): \(error.localizedDescription)")
            }
        }
    }

    /// Filled in place, so a list the driver has open stays put.
    @MainActor
    private func fillLists(_ environment: AppEnvironment) {
        guard let lists else { return }
        // The car sets how many rows a list may show; more would be cut off or refused.
        let menu = CarPlayMenu.build(from: environment.repository, limit: Int(CPListTemplate.maximumItemCount))
        lists.favorites.updateSections([CPListSection(items: menu.favorites.map { row($0, queue: menu.favorites) })])
        lists.recent.updateSections([CPListSection(items: menu.recent.map { row($0, queue: menu.recent) })])
        lists.library.updateSections([CPListSection(items: menu.groups.map(groupRow))])
        lists.browser.fill(menu: menu, environment: environment)
    }

    @MainActor
    private func groupRow(_ group: CarPlayMenu.Group) -> CPListItem {
        let item = CPListItem(text: group.title, detailText: String(appLocalized: "\(group.items.count) items"))
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                guard let self else { return completion() }
                let rows = group.items.map { self.row($0, queue: group.items) }
                let template = CPListTemplate(title: group.title, sections: [CPListSection(items: rows)])
                self.interfaceController?.pushTemplate(template, animated: true) { _, _ in completion() }
            }
        }
        return item
    }

    /// Plays in the window: the lists close so the video, or why it's waiting, shows.
    @MainActor
    private func row(_ media: MediaItem, queue: [MediaItem]) -> CPListItem {
        let item = CarPlayRows.item(for: media, artwork: artwork)
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                AppEnvironment.current?.playback.play(media, queue: queue, from: .car)
                self?.closeBrowser()
                self?.backToWindow()
                completion()
            }
        }
        return item
    }

    @MainActor
    private func backToWindow() {
        guard let interfaceController, interfaceController.templates.count > 1 else { return }
        interfaceController.popToRootTemplate(animated: true, completion: nil)
    }
}

private extension CarPlayWindowSceneDelegate {
    @MainActor
    func showBrowserStartPage() {
        guard let interfaceController, let template = lists?.browser.template else { return }
        interfaceController.popToRootTemplate(animated: false) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.interfaceController?.pushTemplate(template, animated: true, completion: nil)
            }
        }
    }

    @MainActor
    func openBrowser(_ url: URL) {
        guard let carBrowser, let environment = AppEnvironment.current, environment.proAccess.isPro else { return }
        if environment.playback.origin == .car { environment.playback.stop() }
        carBrowser.open(url)
        browserControls?.reset()
        refresh()
        backToWindow()
    }

    @MainActor
    func closeBrowser() {
        carBrowser?.close()
        browserControls?.reset()
        shownState = nil
        refresh()
    }
}

extension CarPlayWindowSceneDelegate {
    // MARK: Moving the video's place

    /// CarPlay passes a drag on the window as a map pan; over the video it moves the video's place instead.
    nonisolated func mapTemplateDidBeginPanGesture(_ mapTemplate: CPMapTemplate) {
        MainActor.assumeIsolated {
            if let browser = carBrowser, browser.isOpen {
                browser.beginPan()
            } else {
                Self.perform { screen.scrubBegan(playback: $0) }
            }
        }
    }

    nonisolated func mapTemplate(
        _ mapTemplate: CPMapTemplate,
        didUpdatePanGestureWithTranslation translation: CGPoint,
        velocity: CGPoint
    ) {
        MainActor.assumeIsolated {
            if let browser = carBrowser, browser.isOpen {
                browser.pan(by: translation)
            } else {
                screen.scrubMoved(by: translation.x)
            }
        }
    }

    nonisolated func mapTemplate(_ mapTemplate: CPMapTemplate, didEndPanGestureWithVelocity velocity: CGPoint) {
        MainActor.assumeIsolated {
            if carBrowser?.isOpen != true { Self.perform { screen.scrubEnded(playback: $0) } }
        }
    }
}
