import CarPlay
import OSLog

/// Site shortcuts and search. The window prototype opens its own browser; the media app keeps its phone handoff.
@MainActor
final class CarPlayBrowserTab: NSObject, CPSearchTemplateDelegate {
    let template: CPListTemplate
    private weak var interfaceController: CPInterfaceController?
    /// Marks a row to play as video where the car allows it; true when CarPlay then presents it itself.
    private let markAsVideo: (CPListItem) -> Bool
    /// After the page's video starts on a row that presents itself, as PlayCarTV's own window does (DECISIONS 152).
    private let onPlay: () -> Void
    private let openPage: ((URL) -> Void)?
    private var searchScope: URL?
    /// Each site's solid tile, made once per icon (`SiteIconTile`).
    private var siteTiles: [String: (icon: UIImage, tile: UIImage)] = [:]
    private let logger = Logger(subsystem: "com.playcartv", category: "CarPlay")

    init(
        interfaceController: CPInterfaceController?,
        markAsVideo: @escaping (CPListItem) -> Bool,
        onPlay: @escaping () -> Void = {},
        openPage: ((URL) -> Void)? = nil
    ) {
        self.interfaceController = interfaceController
        self.markAsVideo = markAsVideo
        self.onPlay = onPlay
        self.openPage = openPage
        template = CPListTemplate(title: String(appLocalized: "Browser"), sections: [])
        template.tabImage = UIImage(systemName: "globe")
        super.init()
    }

    func fill(menu: CarPlayMenu, environment: AppEnvironment) {
        var top: [any CPListTemplateItem] = []
        // Apple's guide gives audio and video apps the search template from iOS 27.
        if supportsSearch {
            top.append(searchRow())
        }
        if openPage == nil, environment.browser.foundVideo != nil {
            top.append(videoRow(environment.browser))
        }
        let icons = CPListSection(items: siteItems(menu, icons: environment.siteIcons))
        template.updateSections(top.isEmpty ? [icons] : [CPListSection(items: top), icons])
    }

    // MARK: Search

    private var supportsSearch: Bool {
        if openPage != nil {
            return true
        }
        if #available(iOS 27, *) {
            return true
        }
        return false
    }

    func showSearch(on pageURL: URL? = nil) {
        guard supportsSearch else { return }
        searchScope = pageURL
        let search = CPSearchTemplate()
        search.delegate = self
        interfaceController?.pushTemplate(search, animated: true, completion: nil)
    }

    /// Cars hide the keyboard while driving, so search is an extra way in, never the only one.
    private func searchRow() -> CPListItem {
        let item = CPListItem(
            text: String(appLocalized: "Search or enter website"),
            detailText: nil,
            image: UIImage(systemName: "magnifyingglass")
        )
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                guard let self else { return completion() }
                self.showSearch()
                completion()
            }
        }
        return item
    }

    func searchTemplate(
        _ searchTemplate: CPSearchTemplate,
        updatedSearchText searchText: String,
        completionHandler: @escaping ([CPListItem]) -> Void
    ) {
        let icons = AppEnvironment.current?.siteIcons
        let results = BrowserSearch.results(for: searchText, limit: Int(CPListTemplate.maximumItemCount))
        var rows = results.map { result in
            let item = CPListItem(
                text: result.title,
                detailText: result.detail,
                image: image(for: result, icons: icons)
            )
            item.userInfo = result.url
            return item
        }
        if let url = CarBrowserSiteSearch.url(for: searchText, on: searchScope) {
            let item = CPListItem(
                text: String(appLocalized: "Search YouTube"),
                detailText: searchText,
                image: UIImage(systemName: "play.rectangle")
            )
            item.userInfo = url
            rows.insert(item, at: 0)
        }
        completionHandler(Array(rows.prefix(Int(CPListTemplate.maximumItemCount))))
    }

    func searchTemplate(
        _ searchTemplate: CPSearchTemplate,
        selectedResult item: CPListItem,
        completionHandler: @escaping () -> Void
    ) {
        if let url = item.userInfo as? URL {
            openOnPhone(url, name: item.text ?? WebAddress.displayName(of: url))
        }
        completionHandler()
    }

    private func image(for result: BrowserSearch.Result, icons: SiteIconStore?) -> UIImage? {
        switch result {
        case let .site(site): icons.map { tile(for: site, icons: $0) }
        case .address: UIImage(systemName: "globe")
        case .search: UIImage(systemName: "magnifyingglass")
        }
    }

    // MARK: The page's video

    /// A video PlayCarTV can play on the iPhone's open page, played on this screen by PlayCarTV's player.
    private func videoRow(_ browser: BrowserViewModel) -> CPListItem {
        let title = browser.page?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let item = CPListItem(
            text: String(appLocalized: "Video on this page"),
            detailText: title.isEmpty ? browser.pageURL.map(WebAddress.displayName(of:)) : title,
            image: UIImage(systemName: "play.rectangle.fill")
        )
        let presentsItself = markAsVideo(item)
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                guard let environment = AppEnvironment.current, let media = environment.browser.takeVideo() else {
                    return completion()
                }
                environment.playback.play(media, queue: [media], from: .car)
                guard !presentsItself else {
                    self?.onPlay()
                    return completion()
                }
                self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { _, _ in
                    completion()
                }
            }
        }
        return item
    }

    // MARK: Sites

    /// Each site's icon and name in one row the car wraps across its whole width (iOS 26; up to 24 per row), or one
    /// site per row before. Rows of four left the right half empty on a wide screen (owner, 2026-10-23).
    private func siteItems(_ menu: CarPlayMenu, icons: SiteIconStore) -> [any CPListTemplateItem] {
        guard #available(iOS 26, *) else {
            return menu.sites.map { siteRow($0, image: tile(for: $0, icons: icons)) }
        }
        let columns = CPMaximumNumberOfGridImages
        return menu.siteRows(perRow: columns).map { siteGrid($0, icons: icons) }
    }

    @available(iOS 26, *)
    private func siteGrid(_ sites: [BrowserSite], icons: SiteIconStore) -> CPListImageRowItem {
        let elements = sites.map { site in
            CPListImageRowItemImageGridElement(
                image: tile(for: site, icons: icons),
                imageShape: .roundedRectangle,
                title: site.carDisplayName,
                accessorySymbolName: nil
            )
        }
        let item = CPListImageRowItem(text: nil, imageGridElements: elements, allowsMultipleLines: true)
        item.listImageRowHandler = { [weak self] _, index, completion in
            MainActor.assumeIsolated {
                if sites.indices.contains(index) {
                    self?.openOnPhone(sites[index].url, name: sites[index].name)
                }
                completion()
            }
        }
        return item
    }

    private func siteRow(_ site: BrowserSite, image: UIImage) -> CPListItem {
        let item = CPListItem(text: site.name, detailText: nil, image: image)
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                self?.openOnPhone(site.url, name: site.name)
                completion()
            }
        }
        return item
    }

    /// CarPlay shows a see-through tile behind any clear pixel, so every icon goes in solid.
    private func tile(for site: BrowserSite, icons: SiteIconStore) -> UIImage {
        guard let icon = icons.icon(for: site) else { return SiteIconTile.carPlaceholder(for: site.name) }
        if let made = siteTiles[site.name], made.icon === icon {
            return made.tile
        }
        let tile = SiteIconTile.carTile(from: icon)
        siteTiles[site.name] = (icon, tile)
        return tile
    }

    // MARK: Opening a page

    /// A window browser owns its navigation. The media app retains the existing phone handoff.
    private func openOnPhone(_ url: URL, name: String) {
        if let openPage {
            openPage(url)
            return
        }
        AppEnvironment.current?.router.openInBrowser(url)
        let done = CPAlertAction(title: String(appLocalized: "OK"), style: .cancel) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }
        }
        let alert = CPAlertTemplate(
            titleVariants: [
                String(appLocalized: "\(name) is open on your iPhone. For passengers, or while parked."),
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
}
