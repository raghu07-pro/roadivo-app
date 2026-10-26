import UIKit
import WebKit

/// An independent, desktop-layout browser for the experimental CarPlay window. No phone browser state is reused.
@MainActor
final class CarBrowserController: UIViewController {
    let session: CarBrowserSession
    var page: WebPageController {
        session.selected.page
    }

    var state: WebPageController.State {
        session.selected.state
    }

    private(set) var isOpen = false
    private(set) var isAllowed = false
    var onChange: (() -> Void)?
    var onEditField: ((CarBrowserInputBridge, CarBrowserInputBridge.Request) -> Void)?
    var onInputReset: (() -> Void)?
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let message = UILabel()
    private weak var mountedWebView: WKWebView?
    private var navigationID = UUID()
    private var panStart = CGPoint.zero

    /// `defaultZoom`: each new tab's page zoom; Roadivo's plain car window starts smaller (DECISIONS 162).
    init(defaultZoom: CGFloat = 1) {
        session = CarBrowserSession(defaultZoom: defaultZoom)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        message.font = .preferredFont(forTextStyle: .body)
        message.adjustsFontForContentSizeCategory = true
        message.numberOfLines = 0
        message.textAlignment = .center
        message.backgroundColor = .systemBackground
        for child in [message, progress] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
        }
        NSLayoutConstraint.activate([
            message.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            message.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            message.topAnchor.constraint(equalTo: view.topAnchor),
            message.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            progress.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progress.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])
        mountSelectedTab()
        setAllowed(false)
    }

    private func mountSelectedTab() {
        mountedWebView?.removeFromSuperview()
        let tab = session.selected
        tab.input.onEdit = { [weak self, weak tab] request in
            guard let self, let tab, tab === session.selected, isOpen, isAllowed else { return }
            onEditField?(tab.input, request)
        }
        let webView = tab.page.webView
        mountedWebView = webView
        webView.accessibilityIdentifier = "car.browser.page"
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(webView, at: 0)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        page.onState = { [weak self, weak tab] state in
            guard let self, let tab, isOpen else { return }
            tab.state = state
            guard tab === session.selected else { return }
            progress.progress = Float(state.progress)
            progress.isHidden = !isAllowed || !state.isLoading
            onChange?()
        }
        page.onNavigationStarted = { [weak self, weak tab] in
            tab?.input.invalidate()
            guard let self, let tab, tab === session.selected else { return }
            onInputReset?()
            navigationID = UUID()
            message.isHidden = isAllowed
        }
        page.onLoadError = { [weak self, weak tab] in
            guard let self, let tab, tab === session.selected, isAllowed, isOpen else { return }
            message.text = String(appLocalized: "This page couldn't be loaded. Try reloading it.")
            message.isHidden = false
        }
        progress.progress = Float(state.progress)
        page.webView.pageZoom = tab.zoom
    }

    func open(_ url: URL) {
        guard WebAddress.isWeb(url) else { return }
        loadViewIfNeeded()
        isOpen = true
        session.selected.input.invalidate()
        onInputReset?()
        session.selected.pendingURL = url
        navigationID = UUID()
        if isAllowed {
            loadPendingPage()
        }
    }

    func setAllowed(_ allowed: Bool) {
        loadViewIfNeeded()
        let changed = allowed != isAllowed
        isAllowed = allowed
        session.selected.input.isEnabled = allowed && isOpen
        if !allowed {
            onInputReset?()
        }
        page.webView.isUserInteractionEnabled = allowed
        page.webView.isHidden = !allowed
        progress.isHidden = !allowed || !state.isLoading
        if !allowed {
            message.text = String(
                appLocalized: "Watching in the car is part of Roadivo Pro. Unlock it on your iPhone."
            )
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
        if allowed {
            loadPendingPage()
        }
    }

    func close() {
        onInputReset?()
        isOpen = false
        navigationID = UUID()
        session.reset()
        isAllowed = false
        if isViewLoaded {
            mountSelectedTab()
        }
    }

    private func loadPendingPage() {
        guard let url = session.selected.pendingURL else { return }
        session.selected.pendingURL = nil
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

    @discardableResult
    func newTab() -> Bool {
        guard isAllowed, session.addTab() else { return false }
        activateSelectedTab()
        return true
    }

    func selectTab(_ id: UUID) {
        guard isAllowed, session.select(id) else { return }
        activateSelectedTab()
    }

    func closeTab() {
        guard isAllowed else { return }
        session.closeSelected()
        activateSelectedTab()
    }

    private func activateSelectedTab() {
        onInputReset?()
        navigationID = UUID()
        mountSelectedTab()
        page.webView.setAllMediaPlaybackSuspended(!isAllowed, completionHandler: nil)
        setAllowed(isAllowed)
        message.isHidden = isAllowed
        onChange?()
    }

    func setPageZoom(_ zoom: CGFloat) {
        guard isAllowed else { return }
        session.selected.zoom = min(1.75, max(0.75, zoom))
        page.webView.pageZoom = session.selected.zoom
        onChange?()
    }

    func openInputTest() {
        #if DEBUG
            guard isAllowed else { return }
            onInputReset?()
            navigationID = UUID()
            session.selected.pendingURL = nil
            session.selected.input.resetDiagnostics()
            message.isHidden = true
            page.webView.loadHTMLString(CarBrowserInputFixture.html, baseURL: nil)
        #endif
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
