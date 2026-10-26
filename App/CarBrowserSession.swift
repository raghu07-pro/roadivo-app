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
        var zoom: CGFloat = 1

        init(websiteDataStore: WKWebsiteDataStore) {
            // Desktop sites suit the wide car screen, as in CarTV (DECISIONS 162).
            page = WebPageController(
                websiteDataStore: websiteDataStore, allowsExternalLinks: false, contentMode: .desktop
            )
            page.webView.configuration.userContentController.addUserScript(Self.actualTextSize)
            input = CarBrowserInputBridge(webView: page.webView)
        }

        /// An iPhone's WebKit enlarges text on a desktop page zoomed out to fit, which spilled text out of its
        /// columns on the car's screen (Instagram's, at 75%); with this, text follows the page zoom, as on an iPad
        /// and in CarTV (DECISIONS 163).
        private static let actualTextSize = WKUserScript(
            source: """
            const style = document.createElement('style');
            style.textContent = 'html { -webkit-text-size-adjust: 100% !important; ' +
              'text-size-adjust: 100% !important; }';
            document.documentElement.appendChild(style);
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

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

    init() {
        let store = WKWebsiteDataStore.nonPersistent()
        websiteDataStore = store
        let tab = Tab(websiteDataStore: store)
        tabs = [tab]
        selected = tab
    }

    @discardableResult
    func addTab() -> Bool {
        guard tabs.count < Self.maximumTabs else { return false }
        suspend(selected)
        let tab = Tab(websiteDataStore: websiteDataStore)
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
            let tab = Tab(websiteDataStore: websiteDataStore)
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
        let tab = Tab(websiteDataStore: websiteDataStore)
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
