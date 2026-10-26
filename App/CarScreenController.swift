#if DEBUG
    import SwiftUI
    import UIKit

    /// Roadivo's own car app on the plain CarPlay window (DECISIONS 161–163). The window's video, road and cast
    /// picture (`CarPlayWindowController`) lie underneath; the car browser sits under its bar, beside the iPhone's
    /// screen in the split view, or alone in full screen; `CarScreenView` draws the rest. Every tap lands directly,
    /// with no CarPlay template. Taps are answered in `CarScreenController+Actions.swift`, so members are internal.
    @MainActor
    final class CarScreenController: UIViewController {
        /// A webpage field or dropdown the open page is filling.
        struct Field {
            let bridge: CarBrowserInputBridge
            let request: CarBrowserInputBridge.Request
        }

        let model = CarScreenModel()
        let stage = CarPlayWindowController()
        let browser = CarBrowserController()
        let mirror = CarScreenMirror()
        lazy var overlay = UIHostingController(rootView: CarScreenView(model: model))
        lazy var bar = UIHostingController(rootView: CarScreenBrowserBar(model: model))
        lazy var exitFullScreen = UIHostingController(rootView: CarScreenExitFullScreen(model: model))
        let browserArea = UIView()
        /// The page under the bar, or the whole screen.
        lazy var pageUnderBar = browserArea.topAnchor.constraint(equalTo: bar.view.bottomAnchor)
        lazy var pageFullScreen = browserArea.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        var isFullScreen = false
        let bookmarks = CarBookmarks()
        let history = CarSearchHistory()
        /// Speech to text for the search page, as the iPhone's voice search.
        lazy var voice: VoiceSearchModel? = AppEnvironment.current.map {
            VoiceSearchModel(speech: $0.speech, playback: $0.playback)
        }

        /// Saved pages and every site, over the page under the bar (`showStartPage`).
        lazy var startPage = UIHostingController(rootView: CarBrowserStartPage(model: model))
        /// The iPhone's screen beside the page (`toggleSplit`), or how to cast it while there's none.
        let splitPanel = UIView()
        let splitPicture = UIImageView()
        lazy var splitNote = UIHostingController(rootView: CarSplitPlaceholder(model: model))
        /// About CarTV's share of the screen for the iPhone's portrait picture.
        lazy var splitShown = splitPanel.widthAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.widthAnchor,
            multiplier: 0.28
        )
        lazy var splitHidden = splitPanel.widthAnchor.constraint(equalToConstant: 0)
        /// Each tab's page when last on screen, for its card on the Tabs page.
        var snapshots: [UUID: UIImage] = [:]
        var field: Field?
        var isConnected = false
        var isWatching = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.tintColor = UIColor(Color.roadBrand)
            model.actions = self
            model.icons = AppEnvironment.current?.siteIcons
            model.voice = voice
            model.recentSearches = history.searches
            // The video and road stay clear of CarPlay's dock and the screen's corners, as the page does.
            embed(stage, in: view, within: view.safeAreaLayoutGuide)
            stage.showsRoad = false // Roadivo's own screens fill everything but the video.
            view.addSubview(browserArea)
            embed(browser, in: browserArea)
            embed(startPage, in: browserArea)
            startPage.view.isHidden = true
            addSplitPanel()
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
                bar.view.heightAnchor.constraint(equalToConstant: 40),
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
                splitPanel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                splitPanel.topAnchor.constraint(equalTo: browserArea.topAnchor),
                splitPanel.bottomAnchor.constraint(equalTo: browserArea.bottomAnchor),
                splitHidden,
                browserArea.leadingAnchor.constraint(equalTo: splitPanel.trailingAnchor),
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
            mirror.onFrame = { [weak self] frame in self?.splitPicture.image = frame }
            showLayers()
        }

        /// The split view's left side: the iPhone's picture, or how to cast it, with a line beside the page.
        func addSplitPanel() {
            splitPanel.translatesAutoresizingMaskIntoConstraints = false
            splitPanel.clipsToBounds = true
            splitPanel.backgroundColor = .black
            splitPanel.isHidden = true
            view.addSubview(splitPanel)
            splitPicture.contentMode = .scaleAspectFit
            splitPicture.translatesAutoresizingMaskIntoConstraints = false
            splitPanel.addSubview(splitPicture)
            embed(splitNote, in: splitPanel)
            let line = UIView()
            line.backgroundColor = .separator
            line.translatesAutoresizingMaskIntoConstraints = false
            splitPanel.addSubview(line)
            NSLayoutConstraint.activate([
                splitPicture.leadingAnchor.constraint(equalTo: splitPanel.leadingAnchor),
                splitPicture.trailingAnchor.constraint(equalTo: splitPanel.trailingAnchor),
                splitPicture.topAnchor.constraint(equalTo: splitPanel.topAnchor),
                splitPicture.bottomAnchor.constraint(equalTo: splitPanel.bottomAnchor),
                line.trailingAnchor.constraint(equalTo: splitPanel.trailingAnchor),
                line.topAnchor.constraint(equalTo: splitPanel.topAnchor),
                line.bottomAnchor.constraint(equalTo: splitPanel.bottomAnchor),
                line.widthAnchor.constraint(equalToConstant: 1)
            ])
        }

        /// The car's screen arrived: what plays, the lists and the Cast receiver start following Roadivo.
        func connect() {
            loadViewIfNeeded()
            isConnected = true
            mirror.start(stage: stage) { [weak self] started in self?.mirrorChanged(started: started) }
            model.savedPages = bookmarks.pages
            // The Browser tab's icons and the saved pages', when Discover hasn't fetched them yet.
            let sites = BrowserSite.all + bookmarks.pages.map(\.site)
            Task { await AppEnvironment.current?.siteIcons.refresh(sites) }
            refresh()
            if !isWatching {
                watch()
            }
        }

        /// The car went away: the browser's pages and website data go with it.
        func close() {
            isConnected = false
            field = nil
            snapshots = [:]
            browser.close()
            mirror.stop()
            stage.stopUpdating()
        }

        /// `guide`: the edges to pin to inside `container`; its own edges when nil.
        func embed(_ child: UIViewController, in container: UIView, within guide: UILayoutGuide? = nil) {
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
        func showLayers() {
            let browsing = model.mode == .browser
            // CarPlay's dock is see-through: white behind it, as in CarTV, except beside a video or the iPhone's
            // screen.
            let showsPicture = (model.mode == .player || model.mode == .mirror) && model.state == .video
            view.backgroundColor = showsPicture ? .black : .systemBackground
            if !browsing {
                isFullScreen = false
            }
            let pageShown = browsing && model.page == nil
            browserArea.isHidden = !browsing
            bar.view.isHidden = !pageShown || isFullScreen
            exitFullScreen.view.isHidden = !pageShown || !isFullScreen
            overlay.view.isHidden = model.page == nil && browsing
            startPage.view.isHidden = !(browsing && model.showsStartPage)
            let splits = browsing && model.isSplit
            splitPanel.isHidden = !splits
            let (narrow, wide) = splits ? (splitHidden, splitShown) : (splitShown, splitHidden)
            narrow.isActive = false
            wide.isActive = true
            // The old top goes before the new one, so the two never hold at once.
            let (old, new) = isFullScreen ? (pageUnderBar, pageFullScreen) : (pageFullScreen, pageUnderBar)
            old.isActive = false
            new.isActive = true
        }

        // MARK: - Updates

        /// Redraws when Pro, what's playing, the parked state, Location or the library change.
        func watch() {
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

        func changed() {
            isWatching = false
            guard isConnected else { return }
            refresh()
            watch()
        }

        func refresh() {
            guard isConnected, let environment = AppEnvironment.current else { return }
            let playback = environment.playback
            let parking = environment.parking
            let isPro = environment.proAccess.isPro
            model.menu = CarPlayMenu.build(from: environment.repository)
            model.playingID = playback.current?.id
            model.playingTitle = playback.current?.title
            model.isPlaying = playback.isPlaying
            model.isLive = playback.isLive
            model.isCasting = mirror.isStreaming
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
                setMode(.browser)
                return showSplitPicture()
            }
            setMode(state == .upgrade ? .upgrade : state.showsTabs ? .tabs : .player)
        }

        func setMode(_ mode: CarScreenModel.Mode) {
            if model.mode != mode {
                CarPlayTrace.write("screen shows \(mode), \(model.state)")
                model.mode = mode
            }
            showLayers()
        }

        func browserChanged() {
            model.canGoBack = browser.state.canGoBack
            model.canGoForward = browser.state.canGoForward
            model.pageURL = browser.state.url
            let session = browser.session
            model.tabs = session.tabs.map { tab in
                .init(id: tab.id, title: tab.title, isSelected: tab === session.selected, snapshot: snapshots[tab.id])
            }
            model.canAddTab = session.tabs.count < CarBrowserSession.maximumTabs
            model.isPageSaved = bookmarks.contains(browser.state.url)
            model.pageSize = session.selected.zoom
        }

        /// The iPhone's picture in the split view while it casts and the car is parked, as video; otherwise how to
        /// cast, or why it's off.
        func showSplitPicture() {
            let isParked = AppEnvironment.current?.parking.isParked ?? false
            let showsPicture = model.isSplit && model.mode == .browser && mirror.isStreaming && isParked
            splitPicture.isHidden = !showsPicture
            splitNote.view.isHidden = showsPicture
            if !mirror.isStreaming {
                splitPicture.image = nil
            }
            if !mirror.isShown {
                mirror.decodesFrames(showsPicture)
            }
        }

        /// The open tab's page as it looks now, for its card on the Tabs page.
        func snapshotTab(then done: @escaping () -> Void = {}) {
            let id = browser.session.selected.id
            guard browser.isOpen, !model.showsStartPage else { return done() }
            browser.page.webView.takeSnapshot(with: nil) { [weak self] image, _ in
                if let image {
                    self?.snapshots[id] = image
                }
                done()
            }
        }

        /// A broadcast that starts takes the screen: the car's own video and the browser make way.
        func mirrorChanged(started: Bool) {
            // In the split view the iPhone's screen stays beside the page rather than taking the screen.
            if started, model.isSplit, browser.isOpen {
                mirror.isHidden = true
                return refresh()
            }
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
    }

    // MARK: - Webpage fields

    extension CarScreenController {
        func edit(_ request: CarBrowserInputBridge.Request, with bridge: CarBrowserInputBridge) {
            let kind = request.isSecure ? "password" : request.isSearch ? "search" : "text"
            CarPlayTrace.write("screen field tapped: \(kind), \(request.label)")
            let title = request.label.isEmpty ? request.host : request.label
            if request.options.isEmpty {
                // What's there already, to edit; a password starts empty. Typing starts with the choice of voice,
                // the iPhone or the keyboard, as in CarTV.
                model.searchText = request.value
                model.searchInput = .choose
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
        func apply(_ text: String, to field: Field) {
            field.bridge.apply(text, to: field.request, submit: field.request.isSearch) { [weak self] success in
                CarPlayTrace.write("screen field applied: \(success)")
                guard let self, !success, field.request.isSearch,
                      let results = CarBrowserSiteSearch.url(for: text, on: browser.state.url) else { return }
                browser.open(results)
            }
        }

        func show(_ page: CarScreenModel.Page) {
            model.page = page
            showLayers()
        }
    }
#endif
