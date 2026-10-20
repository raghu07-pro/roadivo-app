import CarPlay
import Observation
import OSLog

/// Roadivo on CarPlay: Favorites, Recent and Library lists, played through the shared player, and a Browser
/// tab of sites. Video goes over AirPlay only while parked in supported cars (sound only when driving); DECISIONS 25.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    /// Filled in place, so a list or Now Playing the driver has open stays put.
    private var tabs: Tabs?
    private var isWatching = false
    /// Each site's solid CarPlay tile, made once per icon (`SiteIconTile`).
    private var siteTiles: [String: (icon: UIImage, tile: UIImage)] = [:]
    private lazy var placeholderTile = SiteIconTile.placeholder()
    private let logger = Logger(subsystem: "com.roadivo", category: "CarPlay")

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        MainActor.assumeIsolated {
            self.interfaceController = interfaceController
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
            AppEnvironment.current?.carConnection.isCarPlayConnected = false
            self.interfaceController = nil
            tabs = nil
        }
    }

    // MARK: Updates

    /// Redraws after a purchase (Pro may still be loading at a cold start), a library change, a new video
    /// (for Recent), or a site's icon arriving.
    @MainActor
    private func watchLibrary() {
        guard let environment = AppEnvironment.current else { return }
        isWatching = true
        withObservationTracking {
            _ = environment.proAccess.isPro
            _ = environment.router.libraryRevision
            _ = environment.playback.current?.id
            _ = environment.siteIcons.icons
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.libraryChanged() }
        }
    }

    @MainActor
    private func libraryChanged() {
        isWatching = false
        guard interfaceController != nil else { return }
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
        interfaceController?.setRootTemplate(rootTemplate(), animated: false) { [logger] _, error in
            if let error {
                logger.error("Root template: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @MainActor
    private func rootTemplate() -> CPTemplate {
        tabs = nil
        guard let environment = AppEnvironment.current else {
            return message(String(appLocalized: "Open Roadivo on your iPhone to get started."))
        }
        guard environment.proAccess.isPro else {
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
            ? list(String(appLocalized: "Browser"), items: [], symbol: "globe")
            : nil
        tabs = Tabs(favorites: favorites, recent: recent, library: library, browser: browser)
        fillTabs()
        return CPTabBarTemplate(templates: [favorites, recent, library, browser].compactMap(\.self))
    }

    @MainActor
    private func fillTabs() {
        guard let tabs, let environment = AppEnvironment.current else { return }
        // The car sets how many rows a list may show; more would be cut off or refused.
        let menu = CarPlayMenu.build(from: environment.repository, limit: Int(CPListTemplate.maximumItemCount))
        tabs.favorites.updateSections([CPListSection(items: menu.favorites.map { row($0, queue: menu.favorites) })])
        tabs.recent.updateSections([CPListSection(items: menu.recent.map { row($0, queue: menu.recent) })])
        tabs.library.updateSections([CPListSection(items: menu.groups.map(groupRow))])
        tabs.browser?.updateSections([CPListSection(items: siteItems(menu, icons: environment.siteIcons))])
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

    @MainActor
    private func row(_ media: MediaItem, queue: [MediaItem]) -> CPListItem {
        let item = CPListItem(
            text: media.title,
            detailText: media.groupTitle,
            image: UIImage(systemName: media.isLocalFile ? "film" : "play.tv")
        )
        if let progress = media.progress {
            item.playbackProgress = progress.fraction
        }
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                AppEnvironment.current?.playback.play(media, queue: queue)
                self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { _, _ in
                    completion()
                }
            }
        }
        return item
    }

    /// The Browser tab: each site's icon and name, in rows the car wraps to fit its screen (iOS 26), or one site
    /// per row before that.
    @MainActor
    private func siteItems(_ menu: CarPlayMenu, icons: SiteIconStore) -> [any CPListTemplateItem] {
        guard #available(iOS 26, *) else {
            return menu.sites.map { siteRow($0, image: tile(for: $0, icons: icons)) }
        }
        return menu.siteRows(perRow: CPMaximumNumberOfGridImages).map { siteGrid($0, icons: icons) }
    }

    @available(iOS 26, *)
    @MainActor
    private func siteGrid(_ sites: [BrowserSite], icons: SiteIconStore) -> CPListImageRowItem {
        let elements = sites.map { site in
            CPListImageRowItemImageGridElement(
                image: tile(for: site, icons: icons),
                imageShape: .roundedRectangle,
                title: site.name,
                accessorySymbolName: nil
            )
        }
        let item = CPListImageRowItem(text: nil, imageGridElements: elements, allowsMultipleLines: true)
        item.listImageRowHandler = { [weak self] _, index, completion in
            MainActor.assumeIsolated {
                if sites.indices.contains(index) {
                    self?.open(sites[index])
                }
                completion()
            }
        }
        return item
    }

    @MainActor
    private func siteRow(_ site: BrowserSite, image: UIImage) -> CPListItem {
        let item = CPListItem(text: site.name, detailText: nil, image: image)
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                self?.open(site)
                completion()
            }
        }
        return item
    }

    /// CarPlay shows a see-through tile behind any clear pixel, so every icon goes in solid.
    @MainActor
    private func tile(for site: BrowserSite, icons: SiteIconStore) -> UIImage {
        guard let icon = icons.icon(for: site) else { return placeholderTile }
        if let made = siteTiles[site.name], made.icon === icon {
            return made.tile
        }
        let tile = SiteIconTile.make(from: icon) ?? icon
        siteTiles[site.name] = (icon, tile)
        return tile
    }

    /// CarPlay can't show a web page, so a site opens in the iPhone's Browser; its videos reach the car over
    /// AirPlay while parked (DECISIONS 131).
    @MainActor
    private func open(_ site: BrowserSite) {
        AppEnvironment.current?.router.openInBrowser(site.url)
        showOpenedOnPhone(site)
    }

    @MainActor
    private func showOpenedOnPhone(_ site: BrowserSite) {
        let done = CPAlertAction(title: String(appLocalized: "OK"), style: .cancel) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }
        }
        let alert = CPAlertTemplate(
            titleVariants: [
                String(appLocalized: "\(site.name) is open on your iPhone. For passengers, or while parked."),
                String(appLocalized: "Opened on your iPhone")
            ],
            actions: [done]
        )
        interfaceController?.presentTemplate(alert, animated: true) { [logger] _, error in
            if let error {
                logger.error("Browser alert: \(error.localizedDescription, privacy: .public)")
            }
        }
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
        let browser: CPListTemplate?
    }
}
