import WebKit

/// Car-only tabs and saved pages live in memory and are discarded when the browser closes.
@MainActor
final class CarBrowserSession {
    @MainActor
    final class Tab: Identifiable {
        let id = UUID()
        let page: WebPageController
        let input: CarBrowserInputBridge
        var state = WebPageController.State()
        var pendingURL: URL?
        var zoom: CGFloat

        init(websiteDataStore: WKWebsiteDataStore, zoom: CGFloat) {
            self.zoom = zoom
            // Desktop sites suit the wide car screen, as in CarTV (DECISIONS 162).
            page = WebPageController(
                websiteDataStore: websiteDataStore, allowsExternalLinks: false, contentMode: .desktop
            )
            input = CarBrowserInputBridge(webView: page.webView)
        }

        var title: String {
            if !state.title.isEmpty {
                return state.title
            }
            return (state.url ?? pendingURL).map(WebAddress.displayName(of:)) ?? String(appLocalized: "New tab")
        }
    }

    struct SavedPage {
        let title: String
        let url: URL
    }

    static let maximumTabs = 6
    private(set) var tabs: [Tab]
    private(set) var selected: Tab
    private(set) var savedPages: [SavedPage] = []
    private var websiteDataStore: WKWebsiteDataStore
    /// Each new tab's page zoom.
    let defaultZoom: CGFloat

    init(defaultZoom: CGFloat = 1) {
        self.defaultZoom = defaultZoom
        let store = WKWebsiteDataStore.nonPersistent()
        websiteDataStore = store
        let tab = Tab(websiteDataStore: store, zoom: defaultZoom)
        tabs = [tab]
        selected = tab
    }

    @discardableResult
    func addTab() -> Bool {
        guard tabs.count < Self.maximumTabs else { return false }
        suspend(selected)
        let tab = Tab(websiteDataStore: websiteDataStore, zoom: defaultZoom)
        tabs.append(tab)
        selected = tab
        return true
    }

    @discardableResult
    func select(_ id: UUID) -> Bool {
        guard let tab = tabs.first(where: { $0.id == id }) else { return false }
        guard tab !== selected else { return true }
        suspend(selected)
        selected = tab
        return true
    }

    func closeSelected() {
        suspend(selected)
        selected.page.stop()
        selected.page.webView.loadHTMLString("", baseURL: nil)
        tabs.removeAll { $0 === selected }
        if let tab = tabs.last {
            selected = tab
        } else {
            let tab = Tab(websiteDataStore: websiteDataStore, zoom: defaultZoom)
            tabs = [tab]
            selected = tab
        }
    }

    func toggleSavedPage() {
        guard let url = selected.state.url, WebAddress.isWeb(url) else { return }
        if let index = savedPages.firstIndex(where: { $0.url == url }) {
            savedPages.remove(at: index)
        } else {
            savedPages.append(SavedPage(title: selected.title, url: url))
        }
    }

    func reset() {
        for tab in tabs {
            suspend(tab)
            tab.page.stop()
            tab.page.webView.loadHTMLString("", baseURL: nil)
        }
        websiteDataStore = .nonPersistent()
        let tab = Tab(websiteDataStore: websiteDataStore, zoom: defaultZoom)
        tabs = [tab]
        selected = tab
        savedPages = []
    }

    private func suspend(_ tab: Tab) {
        tab.input.isEnabled = false
        tab.page.pauseMedia()
        tab.page.webView.setAllMediaPlaybackSuspended(true, completionHandler: nil)
    }
}
