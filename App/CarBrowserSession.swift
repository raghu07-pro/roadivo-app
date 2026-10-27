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
            // A new tab starts at 100%.
            for script in [Self.desktopScreen, Self.viewport(width: CarBrowserSession.pageWidth), Self.actualTextSize] {
                page.webView.configuration.userContentController.addUserScript(script)
            }
            input = CarBrowserInputBridge(webView: page.webView)
        }

        /// How wide this tab's pages lay out: `pageWidth` at 100%, narrower, so drawn bigger, as `zoom` grows.
        private var layoutWidth: Int {
            Int((CGFloat(CarBrowserSession.pageWidth) / zoom).rounded())
        }

        /// Page size: future pages lay out at the new width, and the open one does at once. WebKit's own page zoom
        /// would change nothing visible, as it fits each page's width to the screen.
        func applyPageSize() {
            let scripts = page.webView.configuration.userContentController
            scripts.removeAllUserScripts()
            for script in [Self.desktopScreen, Self.viewport(width: layoutWidth), Self.actualTextSize] {
                scripts.addUserScript(script)
            }
            CarBrowserInputBridge.userScripts.forEach(scripts.addUserScript)
            page.webView.evaluateJavaScript("window.roadivoViewport?.(\(layoutWidth));", completionHandler: nil)
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

        /// Every page lays out `width` wide, in place of its own viewport, and WebKit shrinks it to fit the car's
        /// screen: the same page on every car, scaled to its screen. No zoom: a page zoomed into its search field
        /// stayed zoomed on the results, cut at both sides until Reload (owner, 2026-10-27).
        private static func viewport(width: Int) -> WKUserScript {
            WKUserScript(
                source: """
                (() => {
                  let base = \(width);
                  let current = base;
                  let widened = 0;
                  let content = 'width=\(width), user-scalable=no';
                  let ours = null;
                  const apply = () => {
                    content = 'width=' + current + ', user-scalable=no';
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
                  // A page wider than its layout (YouTube's results beside the split view's Cast) is cut at the sides:
                  // lay it out that wide, so it fits the screen whole. Three times at most, as some grow with it.
                  const fit = () => {
                    const wide = Math.ceil(document.documentElement.scrollWidth);
                    if (wide > current + 8 && widened < 3 && wide <= base * 3) {
                      current = wide;
                      widened += 1;
                      apply();
                    }
                  };
                  // A new page size, for the page that's open (`applyPageSize`).
                  window.roadivoViewport = width => {
                    base = width;
                    current = width;
                    widened = 0;
                    apply();
                  };
                  document.addEventListener('DOMContentLoaded', () => {
                    apply();
                    new MutationObserver(apply).observe(document.head, {childList: true});
                  });
                  // Pages that change without loading again (YouTube's search) are checked every second too.
                  window.addEventListener('load', fit);
                  setInterval(fit, 1000);
                })();
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        }

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
