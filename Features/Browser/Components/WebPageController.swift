import SwiftUI
import WebKit

/// The Browser's one web view and what it reports: where it is, whether it can go back or forward,
/// how far it has loaded, and videos PlayCarTV's player can take. Owned by
/// `BrowserViewModel`, so an open page survives switching tabs.
@MainActor
final class WebPageController: NSObject {
    struct State: Equatable {
        var url: URL?
        var title = ""
        var canGoBack = false
        var canGoForward = false
        var isLoading = false
        var progress = 0.0
    }

    let webView: WKWebView
    var onState: ((State) -> Void)?
    var onNavigationStarted: (() -> Void)?
    /// A video PlayCarTV's player can take: the page itself, or a `<video>` the page started.
    var onVideo: ((URL) -> Void)?
    /// The page started playing anything, so PlayCarTV's own playback can make way.
    var onMediaStarted: (() -> Void)?
    var onLoadError: (() -> Void)?

    private var observations: [NSKeyValueObservation] = []
    private let allowsExternalLinks: Bool
    private static let messageName = "playcartvMedia"

    /// Reports every `<video>` or `<audio>` that starts, with the video's address when it has one.
    private static let mediaScript = """
    document.addEventListener('play', function (event) {
      var media = event.target;
      var source = media && media.tagName === 'VIDEO' ? (media.currentSrc || media.src || '') : '';
      window.webkit.messageHandlers.\(messageName).postMessage({ src: source });
    }, true);
    """

    init(
        websiteDataStore: WKWebsiteDataStore = .default(),
        allowsExternalLinks: Bool = true,
        contentMode: WKWebpagePreferences.ContentMode = .recommended
    ) {
        self.allowsExternalLinks = allowsExternalLinks
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = websiteDataStore
        configuration.defaultWebpagePreferences.preferredContentMode = contentMode
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        let content = webView.configuration.userContentController
        // Through a weak relay: the content controller keeps its handlers alive.
        content.add(WeakScriptHandler(self), name: Self.messageName)
        content.addUserScript(
            WKUserScript(source: Self.mediaScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        )
        observe()
    }

    func load(_ url: URL) {
        loader(webView, url)
    }

    /// How a page is loaded; unit tests swap it out so they never reach the network.
    var loader: (WKWebView, URL) -> Void = { view, url in
        view.load(URLRequest(url: url))
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    func reload() {
        webView.reload()
    }

    func stop() {
        webView.stopLoading()
    }

    func pauseMedia() {
        webView.pauseAllMediaPlayback(completionHandler: nil)
    }

    /// Reported together, so the bar never shows a half-updated page.
    private func observe() {
        let changed: @Sendable (WKWebView) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.publish() }
        }
        observations = [
            webView.observe(\.url) { view, _ in changed(view) },
            webView.observe(\.title) { view, _ in changed(view) },
            webView.observe(\.canGoBack) { view, _ in changed(view) },
            webView.observe(\.canGoForward) { view, _ in changed(view) },
            webView.observe(\.isLoading) { view, _ in changed(view) },
            webView.observe(\.estimatedProgress) { view, _ in changed(view) }
        ]
    }

    private func publish() {
        onState?(State(
            url: webView.url,
            title: webView.title ?? "",
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward,
            isLoading: webView.isLoading,
            progress: webView.estimatedProgress
        ))
    }
}

// MARK: - Navigation

extension WebPageController: WKNavigationDelegate {
    /// Everything stays in the Browser, as in CarTV (owner, 2026-10-19): other apps' links (youtube:,
    /// the App Store) are ignored, and a tapped link to another site loads here directly, so iOS doesn't
    /// hand it to that site's app. Mail and phone links still open when tapped.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else { return .allow }
        let isTap = navigationAction.navigationType == .linkActivated
        if scheme == "mailto" || scheme == "tel" {
            if isTap, allowsExternalLinks {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return .cancel
        }
        guard ["http", "https", "about", "blob", "data"].contains(scheme) else { return .cancel }
        // A load the app starts never opens another app; a tapped link to another site could.
        if isTap, WebAddress.isWeb(url), navigationAction.targetFrame?.isMainFrame != false,
           url.host() != webView.url?.host() {
            webView.load(navigationAction.request)
            return .cancel
        }
        return .allow
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse
    ) async -> WKNavigationResponsePolicy {
        let response = navigationResponse.response
        if navigationResponse.isForMainFrame, let url = response.url,
           WebMedia.isPlayablePage(url, mimeType: response.mimeType) {
            onVideo?(url)
        }
        return .allow // WebKit plays it too, with its own AirPlay button.
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
        onNavigationStarted?()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled {
            onLoadError?()
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled {
            onLoadError?()
        }
    }

    /// iOS ended the page's process to free memory: load it again rather than show a blank page.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

// MARK: - Windows and media

extension WebPageController: WKUIDelegate {
    /// A link that asks for a new window opens here: the Browser shows one page at a time.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

extension WebPageController: WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageName else { return }
        onMediaStarted?()
        let source = (message.body as? [String: Any])?["src"] as? String
        if let url = source.flatMap(URL.init(string:)), WebMedia.isPlayableSource(url) {
            onVideo?(url)
        }
    }
}

/// Passes script messages on without keeping the controller alive.
@MainActor
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

/// Shows the controller's web view; the controller, not SwiftUI, owns it.
struct WebView: UIViewRepresentable {
    let controller: WebPageController

    func makeUIView(context: Context) -> WKWebView {
        controller.webView
    }

    func updateUIView(_ view: WKWebView, context: Context) {}
}
