#if DEBUG
    import SwiftUI
    import UIKit

    extension CarScreenController: CarScreenActions {
        func select(_ tab: CarScreenModel.Tab) {
            // Browser opens the browser itself on its Start Page, as CarTV's does; the tab underneath stays.
            if tab == .browser {
                return openBrowserStartPage()
            }
            model.tab = tab
            // Cast while the iPhone still casts shows it again, as Home only stepped back to the tabs.
            if tab == .cast, mirror.isStreaming {
                mirror.isHidden = false
                refresh()
            }
        }

        func play(_ media: MediaItem, queue: [MediaItem]) {
            // A search or results page steps aside, or the video would start hidden behind it.
            closePage()
            if browser.isOpen {
                browser.close()
            }
            AppEnvironment.current?.playback.play(media, queue: queue, from: .car)
            refresh()
        }

        func playback(_ action: (PlaybackController) -> Void) {
            if let playback = AppEnvironment.current?.playback {
                action(playback)
            }
        }

        func stopPlayback() {
            AppEnvironment.current?.playback.stop()
        }

        func scrubBegan() {
            if let playback = AppEnvironment.current?.playback {
                stage.scrubBegan(playback: playback)
            }
        }

        func scrubMoved(by distance: CGFloat) {
            stage.scrubMoved(by: distance)
        }

        func scrubEnded() {
            if let playback = AppEnvironment.current?.playback {
                stage.scrubEnded(playback: playback)
            }
        }

        func open(_ url: URL) {
            guard let environment = AppEnvironment.current, environment.proAccess.isPro else { return }
            closePage()
            if environment.playback.origin == .car {
                environment.playback.stop()
            }
            model.showsStartPage = false
            browser.open(url)
            refresh()
        }

        func closeBrowser() {
            closePage()
            model.showsStartPage = false
            model.isSplit = false
            snapshots = [:]
            browser.close()
            refresh()
        }

        func browserBack() {
            browser.back()
        }

        func browserForward() {
            browser.forward()
        }

        func browserReload() {
            browser.reload()
        }

        func setBrowserFullScreen(_ isFullScreen: Bool) {
            self.isFullScreen = isFullScreen
            showLayers()
        }

        /// The browser on its Start Page, from the Browser tab.
        private func openBrowserStartPage() {
            guard let environment = AppEnvironment.current, environment.proAccess.isPro else { return }
            closePage()
            if environment.playback.origin == .car {
                environment.playback.stop()
            }
            model.showsStartPage = true
            browser.openBlank()
            refresh()
            browserChanged()
        }

        // MARK: Searching

        func showLibrarySearch() {
            field = nil
            readLibrary()
            model.searchText = ""
            model.searchInput = .choose
            model.recentSearches = history.searches
            let title = String(appLocalized: "Search channels and titles")
            show(.search(.init(title: title, isSearch: true, isField: false, scope: nil, isLibrary: true)))
        }

        func chooseKeyboard() {
            voice?.cancel()
            CarPhoneInput.shared.end()
            model.searchInput = .keyboard
        }

        func startVoice() {
            CarPhoneInput.shared.end()
            model.searchInput = .voice
            voice?.toggle { [weak self] text in
                self?.model.searchText = text
            } onFinish: { [weak self] in
                self?.voiceFinished()
            }
        }

        func stopVoice() {
            if voice?.isListening == true {
                voice?.toggle { _ in } // Stops; the listening started in `startVoice` then finishes.
            } else {
                model.searchInput = .choose
            }
        }

        /// A search runs by itself when the speaking stops; a webpage's field waits for Done.
        private func voiceFinished() {
            guard model.searchInput == .voice else { return }
            model.searchInput = .choose
            guard case let .search(search) = model.page, !search.isField, !model.searchText.isEmpty else { return }
            submitSearch()
        }

        func startPhoneInput() {
            guard case let .search(search) = model.page else { return }
            voice?.cancel()
            model.searchInput = .phone
            CarPhoneInput.shared.begin(
                .init(title: search.title, isSearch: search.isSearch, isSecure: search.isSecure),
                text: model.searchText
            ) { [weak self] text in
                self?.model.searchText = text
            } onSubmit: { [weak self] in
                self?.submitSearch()
            }
        }

        func searchAgain(_ search: String) {
            model.searchText = search
            submitSearch()
        }

        func clearRecentSearches() {
            history.clear()
            model.recentSearches = []
        }

        // MARK: The browser's options

        func showStartPage() {
            model.showsStartPage = true
            showLayers()
        }

        func showTabs() {
            snapshotTab { [weak self] in
                self?.browserChanged()
                self?.show(.tabs)
            }
        }

        /// A new tab opens on the Start Page, as CarTV's does.
        func newTab() {
            snapshotTab()
            guard browser.newTab() else { return }
            closePage()
            model.showsStartPage = true
            browserChanged()
            showLayers()
        }

        func selectTab(_ id: UUID) {
            snapshotTab()
            browser.selectTab(id)
            closePage()
            model.showsStartPage = browser.state.url == nil
            browserChanged()
            showLayers()
        }

        func closeTab(_ id: UUID) {
            browser.selectTab(id)
            browser.closeTab()
            snapshots[id] = nil
            model.showsStartPage = browser.state.url == nil
            browserChanged()
            show(.tabs)
        }

        func toggleSavedPage() {
            guard let url = browser.state.url else { return }
            bookmarks.toggle(title: browser.session.selected.title, url: url)
            model.savedPages = bookmarks.pages
            browserChanged()
            let sites = bookmarks.pages.map(\.site)
            Task { await AppEnvironment.current?.siteIcons.refresh(sites) }
        }

        func showPageSize() {
            browserChanged()
            show(.pageSize)
        }

        /// On a 5% grid, so repeated steps don't drift; the menu stays open to show the new size.
        func setPageSize(_ size: CGFloat) {
            browser.setPageZoom((size * 20).rounded() / 20)
            browserChanged()
        }

        func toggleSplit() {
            model.isSplit.toggle()
            showLayers()
            showSplitPicture()
        }

        func showSearch(in page: URL?) {
            field = nil
            model.searchText = ""
            let title = page.map(WebAddress.displayName(of:)) ?? String(appLocalized: "Search or enter website")
            model.searchInput = .choose
            show(.search(.init(title: title, isSearch: true, isField: false, scope: page)))
        }

        /// Into the webpage's field; otherwise YouTube's search on YouTube, else the first suggestion.
        func submitSearch() {
            let text = model.searchText
            if let field {
                closePage()
                return apply(text, to: field)
            }
            let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // The library's search is remembered and its results fill the screen, as CarTV's.
            if case let .search(search) = model.page, search.isLibrary {
                guard !query.isEmpty else { return }
                history.record(text)
                model.recentSearches = history.searches
                voice?.cancel()
                CarPhoneInput.shared.end()
                model.searchInput = .choose
                return show(.results(search, source: nil))
            }
            guard !query.isEmpty, case let .search(search) = model.page,
                  let url = CarBrowserSiteSearch.url(for: query, on: search.scope)
                  ?? BrowserSearch.results(for: query, limit: 1).first?.url else { return }
            open(url)
        }

        func choose(_ index: Int) {
            guard let field else { return closePage() }
            closePage()
            field.bridge.choose(index, for: field.request) { CarPlayTrace.write("screen dropdown chosen: \($0)") }
        }

        func closePage() {
            field = nil
            voice?.cancel()
            CarPhoneInput.shared.end()
            guard model.page != nil else { return }
            model.page = nil
            showLayers()
        }

        func hideMirror() {
            mirror.isHidden = true
            model.tab = .home
            refresh()
        }

        func endMirroring() {
            BroadcastSignal.requestStop()
        }

        func toggleMirrorFill() {
            stage.toggleMirrorFill()
        }
    }
#endif
