#if DEBUG
    import Observation
    import UIKit

    /// What `CarScreenController` does when the car screen is tapped.
    @MainActor
    protocol CarScreenActions: AnyObject {
        func select(_ tab: CarScreenModel.Tab)
        func play(_ media: MediaItem, queue: [MediaItem])
        func playback(_ action: (PlaybackController) -> Void)
        func stopPlayback()
        /// The player's heart, for what's playing.
        func toggleFavorite()
        /// Fit, Fill, Stretch, and round again, as CarTV's.
        func cycleAspect()
        /// The iPhone's Cast picture beside a smaller video, or the video alone again.
        func setPlayerSplit(_ isSplit: Bool)
        func closeChannels()
        func open(_ url: URL)
        func closeBrowser()
        func browserBack()
        func browserForward()
        func browserReload()
        /// The page alone, with only the button that brings the bar back; or the bar again.
        func setBrowserFullScreen(_ isFullScreen: Bool)
        /// The browser's options, as in the CarPlay browser's More menu and CarTV's bar.
        func showStartPage()
        func showTabs()
        func newTab()
        func selectTab(_ id: UUID)
        func closeTab(_ id: UUID)
        func toggleSavedPage()
        func showPageSize()
        func setPageSize(_ size: CGFloat)
        func toggleSplit()
        /// The casting screen's split button: the browser beside the iPhone's Cast picture.
        func showBrowserBesideCast()
        /// The library's search, from the round button beside the tabs.
        func showLibrarySearch()
        /// Maps' search for a place, and a place found there, whose routes then show on both screens.
        func showPlaceSearch()
        func choosePlace(_ suggestion: PlaceSuggestion)
        /// Show on iPhone, from the car's route card.
        func showRouteOnPhone()
        /// How to type on a search page: speak, or Roadivo's keyboard.
        func chooseKeyboard()
        func startVoice()
        func stopVoice()
        func startPhoneInput()
        func searchAgain(_ search: String)
        func clearRecentSearches()
        /// The library search's results: every source, or one source's alone.
        func showResults(from source: UUID?)
        /// Back to the search page from its results, to change the search; `speaking` starts Voice Input there.
        func editSearch(speaking: Bool)
        /// Reads the library again, for videos added since the search opened.
        func reloadResults()
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
            case maps
            case cast
            case browser

            var title: LocalizedStringResource {
                switch self {
                case .home: "Home"
                case .favorites: "Favorites"
                case .library: "Library"
                case .maps: "Maps"
                case .cast: "Cast"
                case .browser: "Browser"
                }
            }

            /// Maps only while the iPhone shows it too (`ROADIVO_DIRECTIONS`).
            static var shown: [Tab] {
                allCases.filter { $0 != .maps || DirectionsAvailability.isEnabled }
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
            case tabs
            case pageSize
            /// The library search's results, as CarTV's: every source's, or one source's (`source`).
            case results(CarSearch, source: UUID?)
        }

        /// A car browser tab, for the Tabs page.
        struct BrowserTab: Identifiable, Equatable {
            let id: UUID
            let title: String
            let isSelected: Bool
            /// The tab's page when last on screen, for its card.
            let snapshot: UIImage?
        }

        /// A page saved with the star, for the Browser tab and the Start Page (`CarBookmarks`).
        struct SavedPage: Identifiable, Equatable, Codable {
            let title: String
            let url: URL

            var id: URL {
                url
            }

            /// As a site tile, with the site's own icon.
            var site: BrowserSite {
                BrowserSite(name: title, url: url)
            }
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
            /// Roadivo's own channels and titles rather than the web: results play, and searches are remembered.
            var isLibrary = false
            /// Maps' place search: a place found opens its routes (DECISIONS 172).
            var isPlace = false
        }

        /// How a search page is being typed into: first a choice of voice, the iPhone or Roadivo's keyboard, as in
        /// CarTV.
        enum SearchInput: Equatable {
            case choose
            case keyboard
            case voice
            /// The iPhone's own keyboard, in a sheet in Roadivo on the iPhone (`CarPhoneInput`).
            case phone
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
        /// What's playing is a favourite: the player's heart is filled.
        var isPlayingFavorite = false
        /// What next and previous step through, usually the playing item's group, for the channels panel.
        var playingQueue: [MediaItem] = []
        var playingGroup: String?
        /// How the car's video fills the screen (owner, 2026-10-26; DECISIONS 164).
        var aspect = VideoAspect.fit
        /// The channels panel over the video, as CarTV's Channels button opens it.
        var showsChannels = false
        /// The iPhone's Cast picture beside a smaller video, from the player's split button, as the browser's split.
        var isPlayerSplit = false
        var channelList = ChannelList.group
        var isLive = false
        var playingID: UUID?
        var playingTitle: String?
        /// The browser's page, which scopes its search.
        var pageURL: URL?
        var canGoBack = false
        var canGoForward = false
        var tabs: [BrowserTab] = []
        var canAddTab = true
        var savedPages: [SavedPage] = []
        /// The open page is saved: the star is filled.
        var isPageSaved = false
        /// The Start Page fills the browser under its bar, as CarTV's home does: saved pages and every site.
        var showsStartPage = false
        /// The iPhone's screen beside the page, as CarTV's split view (DECISIONS 163).
        var isSplit = false
        /// The iPhone casts, for the split view's left side.
        var isCasting = false
        /// The tab's page size; 1 is 100%.
        var pageSize: CGFloat = 1
        var searchText = ""
        var searchInput = SearchInput.choose
        /// The library's videos, read when its search opens.
        var library: [MediaItem] = []
        /// Each source's name, for the results' sections.
        var sourceNames: [UUID: String] = [:]
        var recentSearches: [String] = []
        /// Places for what's typed on Maps' search, apart from the iPhone's own search.
        var placeSearch = DirectionsViewModel.Search.idle
        /// The iPhone's Maps: the same place and routes on both screens.
        @ObservationIgnored var directions: DirectionsViewModel?
        /// Speech to text for the search page; its state shows while it listens.
        @ObservationIgnored var voice: VoiceSearchModel?
        @ObservationIgnored weak var actions: CarScreenActions?
        /// What's playing, for the player's progress bar, which follows it as it plays.
        @ObservationIgnored var playback: PlaybackController?
        /// The Browser tab's icons, and each row's artwork.
        @ObservationIgnored var icons: SiteIconStore?
        @ObservationIgnored let artwork = CarPlayArtwork()

        /// Sites, an address or a web search for what's typed; on YouTube, YouTube's search first.
        var suggestions: [Suggestion] {
            guard case let .search(search) = page, !search.isField, !search.isLibrary, !search.isPlace else {
                return []
            }
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

        /// Channels and titles matching what's typed, as the iPhone's Library search matches them.
        var libraryResults: [MediaItem] {
            let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !needle.isEmpty else { return [] }
            return Array(library.lazy.filter {
                $0.title.localizedStandardContains(needle) || $0.groupTitle.localizedStandardContains(needle)
            }.prefix(CarPlayMenu.itemLimit))
        }

        func items(in group: String) -> [MediaItem] {
            menu.groups.first { $0.title == group }?.items ?? []
        }
    }
#endif
