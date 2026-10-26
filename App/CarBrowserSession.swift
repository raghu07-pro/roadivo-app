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
            // WebKit's normal mode, whose pages honour their viewport (`desktopViewport`); desktop mode lays every
            // page out at the screen's own width and undoes any zoom. Sites still see desktop Safari
            // (`desktopUserAgent`, `desktopScreen`), so they send desktop pages, as in CarTV (DECISIONS 163).
            page = WebPageController(
                websiteDataStore: websiteDataStore, allowsExternalLinks: false, contentMode: .mobile
            )
            page.webView.customUserAgent = CarBrowserSession.desktopUserAgent
            let scripts = page.webView.configuration.userContentController
            for script in [Self.desktopScreen, Self.desktopViewport, Self.actualTextSize] {
                scripts.addUserScript(script)
            }
            input = CarBrowserInputBridge(webView: page.webView)
        }

        /// A Mac with no touch and the car's screen: sites treat a touch Mac as an iPad and send tablet pages
        /// (Instagram's "Get the full experience with the tablet app"), an iPhone platform as a phone, and size for the
        /// iPhone's screen rather than the car's. Taps still work, as WebKit turns them into clicks.
        private static let desktopScreen = WKUserScript(
            source: """
            (() => {
              const define = (prototype, name, get) => {
                try { Object.defineProperty(prototype, name, {get, configurable: true}); } catch (error) {}
              };
              define(Navigator.prototype, 'maxTouchPoints', () => 0);
              define(Navigator.prototype, 'platform', () => 'MacIntel');
              for (const name of ['width', 'availWidth']) define(Screen.prototype, name, () => window.innerWidth);
              for (const name of ['height', 'availHeight']) define(Screen.prototype, name, () => window.innerHeight);
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        /// Every page lays out `pageWidth` wide, in place of its own viewport, and WebKit shrinks it to fit the car's
        /// screen: the same page on every car, scaled to its screen.
        private static let desktopViewport = WKUserScript(
            source: """
            (() => {
              const content = 'width=\(CarBrowserSession.pageWidth)';
              let ours = null;
              const apply = () => {
                for (const meta of document.querySelectorAll('meta[name="viewport"]')) {
                  if (meta !== ours) meta.remove();
                }
                if (!ours) {
                  ours = document.createElement('meta');
                  ours.name = 'viewport';
                }
                if (ours.content !== content) ours.content = content;
                const parent = document.head || document.documentElement;
                if (ours.parentNode !== parent) parent.appendChild(ours);
              };
              apply();
              document.addEventListener('DOMContentLoaded', () => {
                apply();
                new MutationObserver(apply).observe(document.head, {childList: true});
              });
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )

        /// An iPhone's WebKit enlarges text on a page shrunk to fit, which spilled text out of its columns on the car's
        /// screen (Instagram's); with this, text keeps the page's own size, as on an iPad and in CarTV.
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
    /// How wide car pages lay out, in CSS pixels; WebKit then shrinks each page to fit the car's screen, so every car
    /// shows the same page, scaled. 1280 is about 75% on a 960-point screen, as CarTV shows pages, and gives YouTube's
    /// Shorts the screen's height. Raise it to fit more, lower it for bigger text (owner, 2026-10-26; DECISIONS 163).
    static let pageWidth = 1280
    /// Desktop Safari's, so sites send desktop pages while WebKit runs in its normal mode.
    static let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/18.6 Safari/605.1.15"
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
