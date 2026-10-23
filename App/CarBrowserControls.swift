import CarPlay

/// Template controls for the prototype: ordinary web links work even when the window receives no direct taps.
@MainActor
final class CarBrowserControls {
    var onSearch: (() -> Void)?
    var onClose: (() -> Void)?
    var onOpen: ((URL) -> Void)?
    private let browser: CarBrowserController
    private let root: CPMapTemplate
    private weak var interface: CPInterfaceController?
    private var lastButtons: Buttons?
    private var linksRequest = UUID()
    private var linkList: CPListTemplate?

    private struct Buttons: Equatable {
        let allowed: Bool
        let back: Bool
        let forward: Bool
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
        let buttons = Buttons(allowed: browser.isAllowed, back: browser.state.canGoBack,
                              forward: browser.state.canGoForward)
        guard buttons != lastButtons else { return }
        lastButtons = buttons
        root.automaticallyHidesNavigationBar = false
        root.hidesButtonsWithNavigationBar = false
        let back = bar("chevron.left") { [weak self] in self?.browser.back() }
        let forward = bar("chevron.right") { [weak self] in self?.browser.forward() }
        back.isEnabled = buttons.allowed && buttons.back
        forward.isEnabled = buttons.allowed && buttons.forward
        let search = bar("magnifyingglass") { [weak self] in self?.onSearch?() }
        search.isEnabled = buttons.allowed
        root.leadingNavigationBarButtons = [back, forward]
        root.trailingNavigationBarButtons = [search, bar("xmark") { [weak self] in self?.onClose?() }]
        guard buttons.allowed else {
            root.mapButtons = []
            return
        }
        root.mapButtons = [
            map("arrow.up") { [weak self] in self?.browser.scrollPage(by: -0.8) },
            map("arrow.down") { [weak self] in self?.browser.scrollPage(by: 0.8) },
            map("list.bullet") { [weak self] in self?.showLinks() }
        ]
    }

    private func bar(_ symbol: String, action: @escaping () -> Void) -> CPBarButton {
        CPBarButton(image: UIImage(systemName: symbol) ?? UIImage()) { _ in
            MainActor.assumeIsolated { action() }
        }
    }

    private func map(_ symbol: String, action: @escaping () -> Void) -> CPMapButton {
        let button = CPMapButton { _ in MainActor.assumeIsolated { action() } }
        button.image = UIImage(systemName: symbol)
        return button
    }

    private func showLinks() {
        let request = UUID()
        linksRequest = request
        browser.links { [weak self] links in
            guard let self, linksRequest == request, browser.isAllowed, browser.isOpen else { return }
            let template = makeLinks(links, startingAt: 0)
            linkList = template
            interface?.pushTemplate(template, animated: true, completion: nil)
        }
    }

    private func makeLinks(_ links: [CarBrowserLink], startingAt start: Int) -> CPListTemplate {
        let capacity = max(1, Int(CPListTemplate.maximumItemCount) - 2)
        let end = min(links.count, start + capacity)
        let reload = CPListItem(text: String(appLocalized: "Reload"), detailText: nil)
        reload.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                if self?.browser.isAllowed == true {
                    self?.browser.reload()
                    self?.interface?.popToRootTemplate(animated: true, completion: nil)
                }
                completion()
            }
        }
        var rows = [reload] + links[start..<end].map { link in
            let row = CPListItem(text: link.title, detailText: WebAddress.displayName(of: link.url))
            row.handler = { [weak self] _, completion in
                MainActor.assumeIsolated {
                    if self?.browser.isAllowed == true { self?.onOpen?(link.url) }
                    completion()
                }
            }
            return row
        }
        if end < links.count {
            let more = CPListItem(text: String(appLocalized: "More links"), detailText: nil)
            more.handler = { [weak self] _, completion in
                MainActor.assumeIsolated {
                    guard let self, self.browser.isAllowed else { return completion() }
                    let next = self.makeLinks(links, startingAt: end)
                    self.linkList?.updateSections(next.sections)
                    completion()
                }
            }
            rows.append(more)
        }
        return CPListTemplate(title: String(appLocalized: "Links on this page"), sections: [CPListSection(items: rows)])
    }
}
