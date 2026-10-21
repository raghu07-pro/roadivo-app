import CarPlay
import Observation
import OSLog

/// Roadivo on CarPlay: Favorites, Recent and Library lists, played through the shared player, and a Browser
/// tab of sites. Where the car offers video, items play as video when parked, else as sound (DECISIONS 132, 139).
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPSessionConfigurationDelegate,
    CPNowPlayingTemplateObserver {
    private var interfaceController: CPInterfaceController?
    /// What the connected car can do, such as video.
    private var session: CPSessionConfiguration?
    /// Filled in place, so a list or Now Playing the driver has open stays put.
    private var tabs: Tabs?
    private var isWatching = false
    private let artwork = CarPlayArtwork()
    private let logger = Logger(subsystem: "com.roadivo", category: "CarPlay")

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        MainActor.assumeIsolated {
            self.interfaceController = interfaceController
            session = CPSessionConfiguration(delegate: self)
            CPNowPlayingTemplate.shared.add(self)
            logVideoSupport()
            AppEnvironment.current?.carConnection.isCarPlayConnected = true
            showRoot()
            if !isWatching {
                watchLibrary()
            }
            // The Browser tab's icons, when Discover hasn't fetched them yet.
            Task { await AppEnvironment.current?.siteIcons.refresh(BrowserSite.all) }
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        MainActor.assumeIsolated {
            trace("disconnect")
            AppEnvironment.current?.carConnection.isCarPlayConnected = false
            CPNowPlayingTemplate.shared.remove(self)
            self.interfaceController = nil
            session = nil
            tabs = nil
        }
    }

    // MARK: Updates

    /// Redraws after a purchase (Pro may still be loading at a cold start), a library change, a new video or
    /// favourite (Recent, Now Playing's heart), a site's icon arriving, or a video found on the iPhone's open page.
    @MainActor
    private func watchLibrary() {
        guard let environment = AppEnvironment.current else { return }
        isWatching = true
        withObservationTracking {
            _ = environment.proAccess.isPro
            _ = environment.router.libraryRevision
            _ = environment.playback.current
            _ = environment.playback.queue.count
            _ = environment.siteIcons.icons
            _ = environment.browser.foundVideo
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.libraryChanged() }
        }
    }

    @MainActor
    private func libraryChanged() {
        isWatching = false
        guard interfaceController != nil else { return }
        trace("refresh, Pro: \(AppEnvironment.current?.proAccess.isPro ?? false), tabs shown: \(tabs != nil)")
        if (AppEnvironment.current?.proAccess.isPro ?? false) == (tabs != nil) {
            fillTabs()
        } else {
            showRoot()
        }
        watchLibrary()
    }

    // MARK: Templates

    @MainActor
    private func showRoot() {
        let root = rootTemplate()
        trace("set root \(type(of: root))")
        interfaceController?.setRootTemplate(root, animated: false) { [weak self, logger] success, error in
            if let error {
                logger.error("Root template: \(error.localizedDescription, privacy: .public)")
            }
            MainActor.assumeIsolated {
                self?.trace("root accepted: \(success), error: \(error.map { String(describing: $0) } ?? "none")")
            }
        }
    }

    @MainActor
    private func rootTemplate() -> CPTemplate {
        tabs = nil
        guard let environment = AppEnvironment.current else {
            trace("no app environment yet")
            return message(String(appLocalized: "Open Roadivo on your iPhone to get started."))
        }
        guard environment.proAccess.isPro else {
            trace("not Pro: message screen")
            return message(
                String(appLocalized: "Watching in the car is part of Roadivo Pro. Unlock it on your iPhone.")
            )
        }
        let favorites = list(String(appLocalized: "Favorites"), items: [], symbol: "heart.fill")
        let recent = list(String(appLocalized: "Recent"), items: [], symbol: "clock.fill")
        let library = list(String(appLocalized: "Library"), items: [], symbol: "play.square.stack.fill")
        library.emptyViewTitleVariants = [String(appLocalized: "Add a source on your iPhone")]
        // Audio apps get four tabs; a car that allows fewer goes without the Browser.
        let browser = CPTabBarTemplate.maximumTabCount > 3
            ? CarPlayBrowserTab(interfaceController: interfaceController) { [weak self] item in
                self?.playsAsVideo(item, times: (elapsed: 0, duration: 0)) ?? false
            }
            : nil
        tabs = Tabs(favorites: favorites, recent: recent, library: library, browser: browser)
        trace("tab bar: \(browser == nil ? 3 : 4) tabs")
        fillTabs()
        return CPTabBarTemplate(templates: [favorites, recent, library, browser?.template].compactMap(\.self))
    }

    @MainActor
    private func fillTabs() {
        guard let tabs, let environment = AppEnvironment.current else { return }
        // The car sets how many rows a list may show; more would be cut off or refused.
        let menu = CarPlayMenu.build(from: environment.repository, limit: Int(CPListTemplate.maximumItemCount))
        tabs.favorites.updateSections([CPListSection(items: menu.favorites.map { row($0, queue: menu.favorites) })])
        tabs.recent.updateSections([CPListSection(items: menu.recent.map { row($0, queue: menu.recent) })])
        tabs.library.updateSections([CPListSection(items: menu.groups.map(groupRow))])
        tabs.browser?.fill(menu: menu, environment: environment)
        updateNowPlaying(environment.playback)
    }

    /// Now Playing's ♥ for what's playing, and Up Next for the rest of its group (DECISIONS 140).
    @MainActor
    private func updateNowPlaying(_ playback: PlaybackController) {
        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.isUpNextButtonEnabled = playback.queue.count > 1
        guard let current = playback.current,
              let heart = UIImage(systemName: current.isFavorite ? "heart.fill" : "heart")
        else {
            return nowPlaying.updateNowPlayingButtons([])
        }
        nowPlaying.updateNowPlayingButtons([
            CPNowPlayingImageButton(image: heart) { [weak self] _ in
                MainActor.assumeIsolated { self?.toggleFavorite() }
            }
        ])
    }

    /// The heart's change reaches the iPhone's lists and this screen through `libraryDidChange`.
    @MainActor
    private func toggleFavorite() {
        guard let environment = AppEnvironment.current, let current = environment.playback.current else { return }
        do {
            let isFavorite = try environment.repository.toggleFavorite(current.id)
            environment.playback.updateFavorite(isFavorite, for: current.id)
            environment.router.libraryDidChange()
        } catch {
            logger.error("Favourite from CarPlay: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// CarPlay calls this on the main thread, though Apple's observer protocol doesn't say so.
    nonisolated func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        MainActor.assumeIsolated { showUpNext() }
    }

    /// What next and previous step through, usually the item's group; choosing one plays it and goes back.
    @MainActor
    private func showUpNext() {
        guard let playback = AppEnvironment.current?.playback else { return }
        let queue = playback.queue
        let rows = queue.prefix(Int(CPListTemplate.maximumItemCount)).map {
            row($0, queue: queue, fromNowPlaying: true)
        }
        let template = CPListTemplate(
            title: playback.current?.groupTitle ?? "",
            sections: [CPListSection(items: rows)]
        )
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    @MainActor
    private func list(_ title: String, items: [MediaItem], symbol: String) -> CPListTemplate {
        let template = CPListTemplate(
            title: title,
            sections: [CPListSection(items: items.map { row($0, queue: items) })]
        )
        template.tabImage = UIImage(systemName: symbol)
        template.emptyViewTitleVariants = [String(appLocalized: "Nothing here yet")]
        return template
    }

    @MainActor
    private func groupRow(_ group: CarPlayMenu.Group) -> CPListItem {
        let item = CPListItem(text: group.title, detailText: String(appLocalized: "\(group.items.count) items"))
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                guard let self else { return completion() }
                let template = self.list(group.title, items: group.items, symbol: "play.square.stack.fill")
                self.interfaceController?.pushTemplate(template, animated: true) { _, _ in completion() }
            }
        }
        return item
    }

    /// A playable row. From Up Next it goes back to Now Playing, which is already open beneath it.
    @MainActor
    private func row(_ media: MediaItem, queue: [MediaItem], fromNowPlaying: Bool = false) -> CPListItem {
        let item = CPListItem(
            text: media.title,
            detailText: media.groupTitle,
            image: UIImage(systemName: media.isLocalFile ? "film" : "play.tv")
        )
        if let picture = artwork.picture(for: media, ready: { [weak item] in item?.setImage($0) }) {
            item.setImage(picture)
        }
        if let progress = media.progress {
            item.playbackProgress = progress.fraction
        }
        item.isPlaying = media.id == AppEnvironment.current?.playback.current?.id
        let presentsItself = playsAsVideo(item, media)
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                AppEnvironment.current?.playback.play(media, queue: queue)
                guard !presentsItself, let interfaceController = self?.interfaceController else { return completion() }
                if fromNowPlaying {
                    interfaceController.popTemplate(animated: true) { _, _ in completion() }
                } else {
                    interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { _, _ in
                        completion()
                    }
                }
            }
        }
        return item
    }

    /// In Xcode's console: whether this build and the connected car can show video, for "sound only" reports.
    @MainActor
    private func logVideoSupport() {
        var carSupportsVideo = false
        #if compiler(>=6.3)
            if #available(iOS 26.4, *) {
                carSupportsVideo = session?.supportsVideoPlayback == true
            }
        #endif
        logger.info("CarPlay connected. Car offers video: \(carSupportsVideo, privacy: .public)")
        trace("""
        connect, iOS \(UIDevice.current.systemVersion), Pro: \(AppEnvironment.current?.proAccess.isPro ?? false), \
        car video: \(carSupportsVideo), tabs allowed: \(CPTabBarTemplate.maximumTabCount), \
        rows allowed: \(CPListTemplate.maximumItemCount)
        """)
    }

    @MainActor
    private func trace(_ line: String) {
        CarPlayTrace.write(line)
    }

    /// In a car that supports video, marks the row to play as video: CarPlay then shows the picture itself while
    /// parked, or Now Playing when it can't. False, and the row unchanged, everywhere else.
    @MainActor
    private func playsAsVideo(_ item: CPListItem, _ media: MediaItem) -> Bool {
        playsAsVideo(item, times: CarPlayMenu.videoTimes(for: media))
    }

    @MainActor
    private func playsAsVideo(_ item: CPListItem, times: (elapsed: Double, duration: Double)) -> Bool {
        // Temporarily keep CarPlay audio-only while investigating the blank scene with Video enabled.
        false
    }

    @MainActor
    private func message(_ text: String) -> CPTemplate {
        let template = CPListTemplate(title: "Roadivo", sections: [])
        template.emptyViewTitleVariants = [text]
        return template
    }

    private struct Tabs {
        let favorites: CPListTemplate
        let recent: CPListTemplate
        let library: CPListTemplate
        let browser: CarPlayBrowserTab?
    }
}
