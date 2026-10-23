import CarPlay

/// Native template actions stay operable when the window cannot receive webpage touches.
@MainActor
final class CarBrowserControls {
    var onSearch: (() -> Void)?
    var onSiteSearch: ((URL) -> Void)?
    var onHome: (() -> Void)?
    var onClose: (() -> Void)?
    var onOpen: ((URL) -> Void)?
    private let browser: CarBrowserController
    private let root: CPMapTemplate
    private weak var interface: CPInterfaceController?
    private var lastButtons: Buttons?
    private var linksRequest = UUID()
    private var linkList: CPListTemplate?
    private var hidesControls = false

    private struct Buttons: Equatable {
        let allowed: Bool
        let back: Bool
        let hidden: Bool
    }

    init(browser: CarBrowserController, root: CPMapTemplate, interface: CPInterfaceController) {
        self.browser = browser
        self.root = root
        self.interface = interface
    }

    func reset() {
        lastButtons = nil
        linksRequest = UUID()
        linkList = nil
        hidesControls = false
    }

    func refresh() {
        guard browser.isOpen else {
            lastButtons = nil
            return
        }
        if !browser.isAllowed {
            linksRequest = UUID()
            if interface?.topTemplate !== root {
                interface?.popToRootTemplate(animated: false, completion: nil)
            }
            linkList = nil
        }
        let buttons = Buttons(allowed: browser.isAllowed, back: browser.state.canGoBack, hidden: hidesControls)
        guard buttons != lastButtons else { return }
        lastButtons = buttons
        root.automaticallyHidesNavigationBar = hidesControls
        root.hidesButtonsWithNavigationBar = false
        let back = bar("chevron.left") { [weak self] in self?.browser.back() }
        back.isEnabled = buttons.allowed && buttons.back
        let search = bar("magnifyingglass") { [weak self] in self?.onSearch?() }
        search.isEnabled = buttons.allowed
        let more = bar("ellipsis.circle") { [weak self] in self?.showOptions() }
        more.isEnabled = buttons.allowed
        root.leadingNavigationBarButtons = [bar("xmark") { [weak self] in self?.onClose?() }, back]
        root.trailingNavigationBarButtons = [search, more]
        guard buttons.allowed else {
            root.mapButtons = []
            return
        }
        let third = hidesControls
            ? map("arrow.down.right.and.arrow.up.left") { [weak self] in self?.toggleControls() }
            : map("list.bullet") { [weak self] in self?.showLinks() }
        root.mapButtons = [
            map("chevron.up") { [weak self] in self?.browser.scrollPage(by: -0.8) },
            map("chevron.down") { [weak self] in self?.browser.scrollPage(by: 0.8) },
            third
        ]
    }

    private func symbol(_ name: String) -> UIImage {
        let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        return UIImage(systemName: name, withConfiguration: configuration) ?? UIImage()
    }

    private func bar(_ name: String, action: @escaping () -> Void) -> CPBarButton {
        CPBarButton(image: symbol(name)) { _ in MainActor.assumeIsolated { action() } }
    }

    private func map(_ name: String, action: @escaping () -> Void) -> CPMapButton {
        let button = CPMapButton { _ in MainActor.assumeIsolated { action() } }
        button.image = symbol(name)
        return button
    }

    private func row(
        _ title: String, symbol name: String, detail: String? = nil,
        enabled: Bool = true, action: @escaping () -> Void
    ) -> CPListItem {
        let item = CPListItem(text: title, detailText: detail, image: symbol(name))
        item.isEnabled = enabled
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                if self?.browser.isAllowed == true { action() }
                completion()
            }
        }
        return item
    }

    private func push(_ title: String, rows: [CPListItem]) {
        let template = CPListTemplate(title: title, sections: [CPListSection(items: rows)])
        interface?.pushTemplate(template, animated: true, completion: nil)
    }

    private func returnToPage() {
        interface?.popToRootTemplate(animated: true, completion: nil)
        lastButtons = nil
        refresh()
    }

    private func toggleControls() {
        hidesControls.toggle()
        returnToPage()
    }

    private func showOptions() {
        guard browser.isAllowed else { return }
        let controlsTitle = hidesControls
            ? String(appLocalized: "Show browser controls") : String(appLocalized: "Hide browser controls")
        var rows = [
            row(String(appLocalized: "Start Page"), symbol: "house") { [weak self] in self?.onHome?() },
            row(String(appLocalized: "Forward"), symbol: "chevron.right", enabled: browser.state.canGoForward) {
                [weak self] in
                self?.browser.forward()
                self?.returnToPage()
            },
            row(String(appLocalized: "Reload"), symbol: "arrow.clockwise") { [weak self] in
                self?.browser.reload()
                self?.returnToPage()
            },
            row(String(appLocalized: "Tabs"), symbol: "square.on.square",
                detail: String(browser.session.tabs.count)) { [weak self] in self?.showTabs() },
            row(String(appLocalized: "Saved pages"), symbol: "star") { [weak self] in self?.showSavedPages() },
            row(String(appLocalized: "Page size"), symbol: "textformat.size",
                detail: "\(Int(browser.session.selected.zoom * 100))%") { [weak self] in self?.showPageSize() },
            row(String(appLocalized: "Links on this page"), symbol: "link") { [weak self] in self?.showLinks() },
            row(controlsTitle,
                symbol: "arrow.up.left.and.arrow.down.right") { [weak self] in self?.toggleControls() }
        ]
        if let url = browser.state.url, CarBrowserSiteSearch.url(for: "test", on: url) != nil {
            rows.insert(row(String(appLocalized: "Search YouTube"), symbol: "magnifyingglass") { [weak self] in
                self?.onSiteSearch?(url)
            }, at: 1)
        }
        push(String(appLocalized: "Browser"), rows: rows)
    }

    private func showTabs() {
        var rows = browser.session.tabs.map { tab in
            row(tab.title, symbol: tab === browser.session.selected ? "checkmark.circle.fill" : "globe",
                detail: tab.state.url.map(WebAddress.displayName(of:))) { [weak self] in
                self?.browser.selectTab(tab.id)
                self?.returnToPage()
            }
        }
        rows += [
            row(String(appLocalized: "New tab"), symbol: "plus",
                enabled: browser.session.tabs.count < CarBrowserSession.maximumTabs) { [weak self] in
                if self?.browser.newTab() == true { self?.onHome?() }
            },
            row(String(appLocalized: "Close tab"), symbol: "xmark") { [weak self] in
                self?.browser.closeTab()
                if self?.browser.state.url == nil { self?.onHome?() } else { self?.returnToPage() }
            }
        ]
        push(String(appLocalized: "Tabs"), rows: rows)
    }

    private func showSavedPages() {
        let url = browser.state.url
        let isSaved = browser.session.savedPages.contains { $0.url == url }
        var rows = [
            row(isSaved ? String(appLocalized: "Remove saved page") : String(appLocalized: "Save this page"),
                symbol: isSaved ? "star.slash" : "star", enabled: url.map(WebAddress.isWeb) == true) { [weak self] in
                self?.browser.session.toggleSavedPage()
                self?.returnToPage()
            }
        ]
        rows += browser.session.savedPages.map { saved in
            row(saved.title, symbol: "globe", detail: WebAddress.displayName(of: saved.url)) { [weak self] in
                self?.onOpen?(saved.url)
            }
        }
        push(String(appLocalized: "Saved pages"), rows: rows)
    }

    private func showPageSize() {
        let rows = [75, 100, 125, 150, 175].map { percent in
            let selected = Int(browser.session.selected.zoom * 100) == percent
            return row("\(percent)%", symbol: selected ? "checkmark" : "textformat") {
                [weak self] in
                self?.browser.setPageZoom(CGFloat(percent) / 100)
                self?.returnToPage()
            }
        }
        push(String(appLocalized: "Page size"), rows: rows)
    }

    private func showLinks() {
        let request = UUID()
        linksRequest = request
        browser.links { [weak self] links in
            guard let self, self.linksRequest == request, self.browser.isAllowed, self.browser.isOpen else { return }
            let template = self.makeLinks(links, startingAt: 0)
            self.linkList = template
            self.interface?.pushTemplate(template, animated: true, completion: nil)
        }
    }

    private func makeLinks(_ links: [CarBrowserLink], startingAt start: Int) -> CPListTemplate {
        let capacity = max(1, Int(CPListTemplate.maximumItemCount) - 2)
        let end = min(links.count, start + capacity)
        let reload = row(String(appLocalized: "Reload"), symbol: "arrow.clockwise") { [weak self] in
            self?.browser.reload()
            self?.returnToPage()
        }
        var rows = [reload] + links[start..<end].map { link in
            row(link.title, symbol: "link", detail: WebAddress.displayName(of: link.url)) { [weak self] in
                self?.onOpen?(link.url)
            }
        }
        if end < links.count {
            rows.append(row(String(appLocalized: "More links"), symbol: "ellipsis") { [weak self] in
                guard let self else { return }
                let next = self.makeLinks(links, startingAt: end)
                self.linkList?.updateSections(next.sections)
            })
        }
        let template = CPListTemplate(
            title: String(appLocalized: "Links on this page"), sections: [CPListSection(items: rows)]
        )
        template.emptyViewTitleVariants = [String(appLocalized: "Nothing here yet")]
        return template
    }
}
