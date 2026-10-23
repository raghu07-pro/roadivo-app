import UIKit
import WebKit

/// An independent, mobile-layout browser for the experimental CarPlay window. No phone browser state is reused.
@MainActor
final class CarBrowserController: UIViewController {
    let page = WebPageController(
        websiteDataStore: .nonPersistent(), allowsExternalLinks: false, prefersMobileContent: true
    )
    private(set) var state = WebPageController.State()
    private(set) var isOpen = false
    private(set) var isAllowed = false
    var onChange: (() -> Void)?
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let message = UILabel()
    private var pendingURL: URL?
    private var navigationID = UUID()
    private var panStart = CGPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        page.webView.accessibilityIdentifier = "car.browser.page"
        message.font = .preferredFont(forTextStyle: .body)
        message.adjustsFontForContentSizeCategory = true
        message.numberOfLines = 0
        message.textAlignment = .center
        message.backgroundColor = .systemBackground
        for child in [page.webView, message, progress] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
        }
        NSLayoutConstraint.activate([
            page.webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            page.webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            page.webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            page.webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            message.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            message.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            message.topAnchor.constraint(equalTo: view.topAnchor),
            message.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            progress.leadingAnchor.constraint(equalTo: page.webView.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: page.webView.trailingAnchor),
            progress.topAnchor.constraint(equalTo: page.webView.topAnchor)
        ])
        page.onState = { [weak self] state in
            guard let self, isOpen else { return }
            self.state = state
            progress.progress = Float(state.progress)
            progress.isHidden = !isAllowed || !state.isLoading
            onChange?()
        }
        page.onNavigationStarted = { [weak self] in
            self?.navigationID = UUID()
            self?.message.isHidden = self?.isAllowed == true
        }
        page.onLoadError = { [weak self] in
            guard let self, isAllowed, isOpen else { return }
            message.text = String(appLocalized: "This page couldn't be loaded. Try reloading it.")
            message.isHidden = false
        }
        setAllowed(false)
    }

    func open(_ url: URL) {
        guard WebAddress.isWeb(url) else { return }
        loadViewIfNeeded()
        isOpen = true
        pendingURL = url
        navigationID = UUID()
        if isAllowed { loadPendingPage() }
    }

    func setAllowed(_ allowed: Bool) {
        loadViewIfNeeded()
        let changed = allowed != isAllowed
        isAllowed = allowed
        page.webView.isUserInteractionEnabled = allowed
        page.webView.isHidden = !allowed
        progress.isHidden = !allowed || !state.isLoading
        if !allowed {
            message.text = String(appLocalized: "Buy a plan")
            message.isHidden = false
        } else if changed {
            message.isHidden = true
        }
        if changed {
            page.webView.setAllMediaPlaybackSuspended(!allowed, completionHandler: nil)
            if !allowed {
                page.pauseMedia()
                page.stop()
            }
        }
        if allowed { loadPendingPage() }
    }

    func close() {
        isOpen = false
        pendingURL = nil
        navigationID = UUID()
        page.pauseMedia()
        page.stop()
        page.webView.setAllMediaPlaybackSuspended(true, completionHandler: nil)
        isAllowed = false
        state = WebPageController.State()
        // Drop the old document so scripts cannot keep running after Close or disconnect.
        page.webView.loadHTMLString("", baseURL: nil)
    }

    private func loadPendingPage() {
        guard let url = pendingURL else { return }
        pendingURL = nil
        message.isHidden = true
        page.load(url)
    }

    func back() {
        guard isAllowed else { return }
        page.goBack()
    }

    func forward() {
        guard isAllowed else { return }
        page.goForward()
    }

    func reload() {
        guard isAllowed else { return }
        message.isHidden = true
        page.reload()
    }

    func scrollPage(by fraction: CGFloat) {
        guard isAllowed else { return }
        let scroll = page.webView.scrollView
        self.scroll(to: scroll.contentOffset.y + scroll.bounds.height * fraction)
    }

    func beginPan() {
        panStart = page.webView.scrollView.contentOffset
    }

    func pan(by translation: CGPoint) {
        guard isAllowed else { return }
        scroll(to: panStart.y - translation.y)
    }

    private func scroll(to offset: CGFloat) {
        let scroll = page.webView.scrollView
        let minimum = -scroll.adjustedContentInset.top
        let bottom = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
        let target = CGPoint(x: scroll.contentOffset.x, y: min(max(minimum, bottom), max(minimum, offset)))
        scroll.setContentOffset(target, animated: false)
    }

    /// Native template rows let knob-only cars follow ordinary links without synthesizing touch events.
    func links(completion: @escaping ([CarBrowserLink]) -> Void) {
        guard isOpen, isAllowed else { return completion([]) }
        let requestID = navigationID
        let script = """
        Array.from(document.querySelectorAll('a[href]')).slice(0, 1000).map(function(a) {
          return {title: (a.innerText || a.getAttribute('aria-label') || a.title || '').trim(), url: a.href};
        });
        """
        page.webView.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self, isOpen, isAllowed, navigationID == requestID else { return completion([]) }
            completion(CarBrowserLink.parse(result as? [[String: String]] ?? []))
        }
    }
}

struct CarBrowserLink: Equatable {
    let title: String
    let url: URL

    static func parse(_ rows: [[String: String]]) -> [CarBrowserLink] {
        var seen: Set<URL> = []
        return rows.compactMap { row in
            guard let raw = row["url"], let url = URL(string: raw), WebAddress.isWeb(url),
                  url.host() != nil, seen.insert(url).inserted else { return nil }
            let title = row["title"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return CarBrowserLink(title: title.isEmpty ? WebAddress.displayName(of: url) : title, url: url)
        }
    }
}

enum CarBrowserAccess {
    static func isAllowed(isPro: Bool) -> Bool {
        #if DEBUG
            return isPro
        #else
            return false
        #endif
    }
}
