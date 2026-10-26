#if DEBUG
    import SwiftUI
    import UIKit

    /// Roadivo's own car app on the plain CarPlay window (DECISIONS 161–163). The window's video, road and cast
    /// picture (`CarPlayWindowController`) lie underneath; the car browser sits under its bar, or alone in full
    /// screen; `CarScreenView` draws the rest. Every tap lands directly, with no CarPlay template.
    @MainActor
    final class CarScreenController: UIViewController {
        /// A webpage field or dropdown the open page is filling.
        private struct Field {
            let bridge: CarBrowserInputBridge
            let request: CarBrowserInputBridge.Request
        }

        /// How much page fits across the car's screen, in CSS pixels: 1024, the narrowest width sites lay out as
        /// desktop,
        /// which on a 960-point car screen is close to CarTV's 100%. Every car shows this width, scaled to its own
        /// screen (`pageZoom(forWidth:)`); raise it to fit more, lower it for bigger text (owner, 2026-10-26;
        /// DECISIONS 163).
        static let pageWidth: CGFloat = 1024
        /// The smallest and largest page zoom, so text stays readable on a small screen and pages don't balloon on a
        /// wide one.
        static let pageZoomRange: ClosedRange<CGFloat> = 0.5...1.25

        /// The zoom that fits `pageWidth` across `width` points of the car's screen.
        static func pageZoom(forWidth width: CGFloat) -> CGFloat {
            min(pageZoomRange.upperBound, max(pageZoomRange.lowerBound, width / pageWidth))
        }

        private let model = CarScreenModel()
        private let stage = CarPlayWindowController()
        private let browser = CarBrowserController()
        private let mirror = CarScreenMirror()
        private lazy var overlay = UIHostingController(rootView: CarScreenView(model: model))
        private lazy var bar = UIHostingController(rootView: CarScreenBrowserBar(model: model))
        private lazy var exitFullScreen = UIHostingController(rootView: CarScreenExitFullScreen(model: model))
        private let browserArea = UIView()
        /// The page under the bar, or the whole screen.
        private lazy var pageUnderBar = browserArea.topAnchor.constraint(equalTo: bar.view.bottomAnchor)
        private lazy var pageFullScreen = browserArea.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        private var isFullScreen = false
        private var field: Field?
        private var isConnected = false
        private var isWatching = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            view.tintColor = UIColor(Color.roadBrand)
            model.actions = self
            model.icons = AppEnvironment.current?.siteIcons
            // The video and road stay clear of CarPlay's dock and the screen's corners, as the page does.
            embed(stage, in: view, within: view.safeAreaLayoutGuide)
            stage.showsRoad = false // Roadivo's own screens fill everything but the video.
            view.addSubview(browserArea)
            embed(browser, in: browserArea)
            overlay.view.backgroundColor = .clear
            bar.view.backgroundColor = .clear
            exitFullScreen.view.backgroundColor = .clear
            for child in [bar, exitFullScreen, overlay] {
                addChild(child)
                child.view.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(child.view)
                child.didMove(toParent: self)
            }
            browserArea.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                bar.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                bar.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                bar.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                bar.view.heightAnchor.constraint(equalToConstant: 52),
                exitFullScreen.view.trailingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                    constant: -Spacing.sm
                ),
                exitFullScreen.view.topAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.topAnchor,
                    constant: Spacing.sm
                ),
                exitFullScreen.view.widthAnchor.constraint(equalToConstant: 48),
                exitFullScreen.view.heightAnchor.constraint(equalToConstant: 48),
                // The safe area leaves out CarPlay's dock and the screen's rounded corners, which hid the page's
                // edges before.
                browserArea.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                browserArea.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                pageUnderBar,
                browserArea.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                overlay.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                overlay.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                overlay.view.topAnchor.constraint(equalTo: view.topAnchor),
                overlay.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            browser.onChange = { [weak self] in self?.browserChanged() }
            browser.onEditField = { [weak self] bridge, request in self?.edit(request, with: bridge) }
            browser.onInputReset = { [weak self] in self?.closePage() }
            showLayers()
        }

        /// The car's screen arrived: what plays, the lists and the Cast receiver start following Roadivo.
        func connect() {
            loadViewIfNeeded()
            isConnected = true
            mirror.start(stage: stage) { [weak self] started in self?.mirrorChanged(started: started) }
            // The Browser tab's icons, when Discover hasn't fetched them yet.
            Task { await AppEnvironment.current?.siteIcons.refresh(BrowserSite.all) }
            refresh()
            if !isWatching {
                watch()
            }
        }

        /// The car went away: the browser's pages and website data go with it.
        func close() {
            isConnected = false
            field = nil
            browser.close()
            mirror.stop()
            stage.stopUpdating()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            fitPage()
        }

        /// Each car's screen is a different size: the page always shows `pageWidth`, scaled to the space it has.
        private func fitPage() {
            let width = browserArea.bounds.width
            guard browser.isOpen, width > 0 else { return }
            let zoom = Self.pageZoom(forWidth: width)
            if abs(browser.session.selected.zoom - zoom) > 0.005 {
                browser.setPageZoom(zoom)
            }
        }

        /// `guide`: the edges to pin to inside `container`; its own edges when nil.
        private func embed(_ child: UIViewController, in container: UIView, within guide: UILayoutGuide? = nil) {
            addChild(child)
            child.view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(child.view)
            NSLayoutConstraint.activate([
                child.view.leadingAnchor.constraint(equalTo: guide?.leadingAnchor ?? container.leadingAnchor),
                child.view.trailingAnchor.constraint(equalTo: guide?.trailingAnchor ?? container.trailingAnchor),
                child.view.topAnchor.constraint(equalTo: guide?.topAnchor ?? container.topAnchor),
                child.view.bottomAnchor.constraint(equalTo: guide?.bottomAnchor ?? container.bottomAnchor)
            ])
            child.didMove(toParent: self)
        }

        /// The browser's page and bar take their own taps; the overlay covers them only for a page.
        private func showLayers() {
            let browsing = model.mode == .browser
            if !browsing {
                isFullScreen = false
            }
            let pageShown = browsing && model.page == nil
            browserArea.isHidden = !browsing
            bar.view.isHidden = !pageShown || isFullScreen
            exitFullScreen.view.isHidden = !pageShown || !isFullScreen
            overlay.view.isHidden = model.page == nil && browsing
            // The old top goes before the new one, so the two never hold at once.
            let (old, new) = isFullScreen ? (pageUnderBar, pageFullScreen) : (pageFullScreen, pageUnderBar)
            old.isActive = false
            new.isActive = true
        }

        // MARK: - Updates

        /// Redraws when Pro, what's playing, the parked state, Location or the library change.
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
            } onChange: { [weak self] in
                Task { @MainActor [weak self] in self?.changed() }
            }
        }

        private func changed() {
            isWatching = false
            guard isConnected else { return }
            refresh()
            watch()
        }

        private func refresh() {
            guard isConnected, let environment = AppEnvironment.current else { return }
            let playback = environment.playback
            let parking = environment.parking
            let isPro = environment.proAccess.isPro
            model.menu = CarPlayMenu.build(from: environment.repository)
            model.playingID = playback.current?.id
            model.playingTitle = playback.current?.title
            model.isPlaying = playback.isPlaying
            model.isLive = playback.isLive
            if mirror.isShown {
                let state = CarWindowState.make(
                    isPro: isPro,
                    isPlaying: true,
                    isParked: parking.isParked,
                    isLocationDenied: parking.isLocationDenied
                )
                model.state = state
                mirror.show(state, playback: playback)
                return setMode(.mirror)
            }
            mirror.hide()
            let state = CarWindowState.make(
                isPro: isPro,
                // Only what was picked on the car; the iPhone's own video stays on the iPhone (DECISIONS 155).
                isPlaying: playback.isActive && playback.origin == .car,
                isParked: parking.isParked,
                isLocationDenied: parking.isLocationDenied
            )
            model.state = state
            stage.show(state, playback: playback)
            if browser.isOpen {
                browser.setAllowed(CarBrowserAccess.isAllowed(isPro: isPro))
                fitPage() // A new page starts at 100% until it's fitted.
                return setMode(.browser)
            }
            setMode(state == .upgrade ? .upgrade : state.showsTabs ? .tabs : .player)
        }

        private func setMode(_ mode: CarScreenModel.Mode) {
            if model.mode != mode {
                CarPlayTrace.write("screen shows \(mode), \(model.state)")
                model.mode = mode
            }
            showLayers()
        }

        private func browserChanged() {
            model.canGoBack = browser.state.canGoBack
            model.canGoForward = browser.state.canGoForward
            model.pageURL = browser.state.url
        }

        /// A broadcast that starts takes the screen: the car's own video and the browser make way.
        private func mirrorChanged(started: Bool) {
            if started {
                if let playback = AppEnvironment.current?.playback, playback.origin == .car {
                    playback.stop()
                }
                closePage()
                if browser.isOpen {
                    browser.close()
                }
            }
            refresh()
        }

        // MARK: - Webpage fields

        private func edit(_ request: CarBrowserInputBridge.Request, with bridge: CarBrowserInputBridge) {
            let kind = request.isSecure ? "password" : request.isSearch ? "search" : "text"
            CarPlayTrace.write("screen field tapped: \(kind), \(request.label)")
            let title = request.label.isEmpty ? request.host : request.label
            if request.options.isEmpty {
                // What's there already, to edit; a password starts empty.
                model.searchText = request.value
                show(.search(.init(
                    title: title,
                    isSearch: request.isSearch,
                    isField: true,
                    scope: browser.state.url,
                    isSecure: request.isSecure,
                    startsWithNumbers: request.isNumeric
                )))
            } else {
                show(.choices(title: title, options: request.options))
            }
            field = Field(bridge: bridge, request: request)
        }

        /// A search the page's form won't submit still reaches YouTube's results.
        private func apply(_ text: String, to field: Field) {
            field.bridge.apply(text, to: field.request, submit: field.request.isSearch) { [weak self] success in
                CarPlayTrace.write("screen field applied: \(success)")
                guard let self, !success, field.request.isSearch,
                      let results = CarBrowserSiteSearch.url(for: text, on: browser.state.url) else { return }
                browser.open(results)
            }
        }

        private func show(_ page: CarScreenModel.Page) {
            model.page = page
            showLayers()
        }
    }

    extension CarScreenController: CarScreenActions {
        func select(_ tab: CarScreenModel.Tab) {
            model.tab = tab
            // Cast while the iPhone still casts shows it again, as Home only stepped back to the tabs.
            if tab == .cast, mirror.isStreaming {
                mirror.isHidden = false
                refresh()
            }
        }

        func play(_ media: MediaItem, queue: [MediaItem]) {
            if browser.isOpen {
                browser.close()
            }
            AppEnvironment.current?.playback.play(media, queue: queue, from: .car)
            refresh()
        }

        func playback(_ action: (PlaybackController) -> Void) {
            if let playback = AppEnvironment.current?.playback {
                action(playback)
            }
        }

        func stopPlayback() {
            AppEnvironment.current?.playback.stop()
        }

        func scrubBegan() {
            if let playback = AppEnvironment.current?.playback {
                stage.scrubBegan(playback: playback)
            }
        }

        func scrubMoved(by distance: CGFloat) {
            stage.scrubMoved(by: distance)
        }

        func scrubEnded() {
            if let playback = AppEnvironment.current?.playback {
                stage.scrubEnded(playback: playback)
            }
        }

        func open(_ url: URL) {
            guard let environment = AppEnvironment.current, environment.proAccess.isPro else { return }
            closePage()
            if environment.playback.origin == .car {
                environment.playback.stop()
            }
            browser.open(url)
            refresh()
        }

        func closeBrowser() {
            closePage()
            browser.close()
            model.tab = .browser
            refresh()
        }

        func browserBack() {
            browser.back()
        }

        func browserForward() {
            browser.forward()
        }

        func browserReload() {
            browser.reload()
        }

        func setBrowserFullScreen(_ isFullScreen: Bool) {
            self.isFullScreen = isFullScreen
            showLayers()
        }

        func showSearch(in page: URL?) {
            field = nil
            model.searchText = ""
            let title = page.map(WebAddress.displayName(of:)) ?? String(appLocalized: "Search or enter website")
            show(.search(.init(title: title, isSearch: true, isField: false, scope: page)))
        }

        /// Into the webpage's field; otherwise YouTube's search on YouTube, else the first suggestion.
        func submitSearch() {
            let text = model.searchText
            if let field {
                closePage()
                return apply(text, to: field)
            }
            let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty, case let .search(search) = model.page,
                  let url = CarBrowserSiteSearch.url(for: query, on: search.scope)
                  ?? BrowserSearch.results(for: query, limit: 1).first?.url else { return }
            open(url)
        }

        func choose(_ index: Int) {
            guard let field else { return closePage() }
            closePage()
            field.bridge.choose(index, for: field.request) { CarPlayTrace.write("screen dropdown chosen: \($0)") }
        }

        func closePage() {
            field = nil
            guard model.page != nil else { return }
            model.page = nil
            showLayers()
        }

        func hideMirror() {
            mirror.isHidden = true
            model.tab = .home
            refresh()
        }

        func endMirroring() {
            BroadcastSignal.requestStop()
        }

        func toggleMirrorFill() {
            stage.toggleMirrorFill()
        }
    }
#endif
