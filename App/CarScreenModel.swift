#if DEBUG
    import Foundation
    import Observation

    /// What `CarScreenController` does when the car screen is tapped.
    @MainActor
    protocol CarScreenActions: AnyObject {
        func select(_ tab: CarScreenModel.Tab)
        func play(_ media: MediaItem, queue: [MediaItem])
        func playback(_ action: (PlaybackController) -> Void)
        func stopPlayback()
        func scrubBegan()
        func scrubMoved(by distance: CGFloat)
        func scrubEnded()
        func open(_ url: URL)
        func closeBrowser()
        func browserBack()
        func browserForward()
        func browserReload()
        /// The page alone, with only the button that brings the bar back; or the bar again.
        func setBrowserFullScreen(_ isFullScreen: Bool)
        /// The search page, for a search or an address; `page` scopes it, as YouTube's search does.
        func showSearch(in page: URL?)
        func submitSearch()
        func choose(_ index: Int)
        func closePage()
        func hideMirror()
        func endMirroring()
        func toggleMirrorFill()
    }

    /// Roadivo's own car screen on the plain CarPlay window (DECISIONS 161–162), drawn by `CarScreenView`: the tabs,
    /// the controls over a video or the iPhone's screen, the browser's toolbar, and full-screen pages for typing.
    @Observable
    @MainActor
    final class CarScreenModel {
        /// As in the CarPlay app's tab bar and CarTV's.
        enum Tab: CaseIterable, Hashable {
            case home
            case favorites
            case library
            case cast
            case browser

            var title: LocalizedStringResource {
                switch self {
                case .home: "Home"
                case .favorites: "Favorites"
                case .library: "Library"
                case .cast: "Cast"
                case .browser: "Browser"
                }
            }
        }

        /// What fills the screen under any page.
        enum Mode: Equatable {
            /// Not Pro: the window's card says watching in the car is part of Pro.
            case upgrade
            case tabs
            /// What the car picked is playing, or the card says why its picture is off.
            case player
            /// The iPhone's screen, from Cast.
            case mirror
            case browser
        }

        /// A full-screen page over everything else.
        enum Page: Equatable {
            case search(CarSearch)
            /// A webpage dropdown's options.
            case choices(title: String, options: [CarBrowserInputBridge.Option])
        }

        /// The search page: into a webpage's own field, or a search or address for the browser.
        struct CarSearch: Equatable {
            /// The field's label, or the page's name.
            let title: String
            /// Submit search for a search box, Done for another field.
            let isSearch: Bool
            /// A webpage's own field: no suggestions, and the text goes into the field.
            let isField: Bool
            /// The page searched from: on YouTube, the first suggestion searches YouTube.
            let scope: URL?
            /// A password field: what's typed shows as dots.
            var isSecure = false
            /// A number or phone field: the keyboard opens on its numbers.
            var startsWithNumbers = false
        }

        /// One suggestion under the search field.
        struct Suggestion: Identifiable, Equatable {
            let title: String
            let detail: String
            let symbol: String
            let url: URL

            var id: URL {
                url
            }
        }

        var mode = Mode.tabs
        var page: Page?
        var tab = Tab.home
        /// The Library group opened from its tab, by title.
        var group: String?
        var menu = CarPlayMenu(favorites: [], recent: [], groups: [], sites: [])
        var state = CarWindowState.home
        var isPlaying = false
        var isLive = false
        var playingID: UUID?
        var playingTitle: String?
        /// The browser's page, which scopes its search.
        var pageURL: URL?
        var canGoBack = false
        var canGoForward = false
        var searchText = ""
        @ObservationIgnored weak var actions: CarScreenActions?
        /// The Browser tab's icons, and each row's artwork.
        @ObservationIgnored var icons: SiteIconStore?
        @ObservationIgnored let artwork = CarPlayArtwork()

        /// Sites, an address or a web search for what's typed; on YouTube, YouTube's search first.
        var suggestions: [Suggestion] {
            guard case let .search(search) = page, !search.isField else { return [] }
            let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return [] }
            var rows = BrowserSearch.results(for: text, limit: 6).map { result in
                let symbol = switch result {
                case .site: "globe"
                case .address: "link"
                case .search: "magnifyingglass"
                }
                return Suggestion(title: result.title, detail: result.detail, symbol: symbol, url: result.url)
            }
            if let youTube = CarBrowserSiteSearch.url(for: text, on: search.scope) {
                rows.insert(
                    Suggestion(
                        title: String(appLocalized: "Search YouTube"),
                        detail: text,
                        symbol: "play.rectangle",
                        url: youTube
                    ),
                    at: 0
                )
            }
            return rows
        }

        func items(in group: String) -> [MediaItem] {
            menu.groups.first { $0.title == group }?.items ?? []
        }
    }
#endif
