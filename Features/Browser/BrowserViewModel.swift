import Foundation
import Observation

/// The Browser: the start page (sites and search) or the open page, its address bar,
/// and a video found on it that Roadivo's player can take (DECISIONS 118).
@Observable
@MainActor
final class BrowserViewModel {
    /// The open page; nil shows the start page.
    private(set) var page: WebPageController.State?
    /// The start page's field, and the open page's address bar while it's being edited.
    var address = ""
    /// Set by the view while the address bar has the keyboard, so loading doesn't overwrite typing.
    var isEditingAddress = false {
        didSet { addressFocusChanged() }
    }

    /// A video on the open page that can play in Roadivo.
    private(set) var foundVideo: URL?

    /// The page started playing something; Roadivo's own playback makes way.
    @ObservationIgnored private let onWebMediaStarted: () -> Void
    @ObservationIgnored private var controller: WebPageController?

    /// The start page's site icons, kept on the iPhone (DECISIONS 129); memory only unless the app passes its own.
    let icons: SiteIconStore

    init(icons: SiteIconStore = SiteIconStore(directory: nil), onWebMediaStarted: @escaping () -> Void = {}) {
        self.icons = icons
        self.onWebMediaStarted = onWebMediaStarted
    }

    /// Made on first use, so the tab costs nothing until someone browses.
    var web: WebPageController {
        if let controller {
            return controller
        }
        let made = WebPageController()
        made.onState = { [weak self] state in self?.stateChanged(state) }
        made.onNavigationStarted = { [weak self] in self?.foundVideo = nil }
        made.onVideo = { [weak self] url in self?.foundVideo = url }
        made.onMediaStarted = { [weak self] in self?.onWebMediaStarted() }
        controller = made
        return made
    }

    var isShowingPage: Bool {
        page != nil
    }

    var pageURL: URL? {
        page?.url
    }

    /// Opens what was typed: an address, or a web search for anything else.
    func open(_ input: String) {
        guard let url = WebAddress.url(for: input) else { return }
        open(url)
    }

    func open(_ url: URL) {
        foundVideo = nil
        page = WebPageController.State(url: url, isLoading: true)
        isEditingAddress = false
        address = WebAddress.displayName(of: url)
        web.load(url)
    }

    func goBack() {
        web.goBack()
    }

    func goForward() {
        web.goForward()
    }

    func reloadOrStop() {
        if page?.isLoading == true {
            web.stop()
        } else {
            web.reload()
        }
    }

    /// Back to the start page; whatever the page was playing stops.
    func closePage() {
        controller?.pauseMedia()
        controller?.stop()
        page = nil
        foundVideo = nil
        address = ""
    }

    func dismissVideo() {
        foundVideo = nil
    }

    /// The found video as a Roadivo item: named after the page, grouped under its site. It isn't saved
    /// to the library, so it plays without adding a source (and without counting against the free one).
    func takeVideo() -> MediaItem? {
        guard let url = foundVideo else { return nil }
        controller?.pauseMedia()
        foundVideo = nil
        let site = pageURL.map(WebAddress.displayName(of:)) ?? WebAddress.displayName(of: url)
        let title = page?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return MediaItem(
            id: UUID(),
            title: title.isEmpty ? site : title,
            group: site,
            artworkURL: nil,
            streamURL: url,
            isLocalFile: false,
            isFavorite: false
        )
    }

    private func stateChanged(_ state: WebPageController.State) {
        // After Start Page, a late report from the stopped page mustn't bring it back.
        guard page != nil else { return }
        page = state
        if !isEditingAddress, let url = state.url {
            address = WebAddress.displayName(of: url)
        }
    }

    /// Editing shows the whole address to change; leaving it shows just the site again.
    private func addressFocusChanged() {
        guard let url = pageURL else { return }
        address = isEditingAddress ? url.absoluteString : WebAddress.displayName(of: url)
    }
}
