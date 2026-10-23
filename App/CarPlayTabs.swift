import CarPlay

/// Centered tabs like CarTV's on the car's home screen (owner, 2026-10-23): Home, Favorites, Library, Cast and
/// Browser in CarPlay's own tab bar, plain lists on CarPlay's wallpaper. The bar covers Roadivo's window, so video,
/// casting and the browser switch back to it. Where CarPlay allows too few tabs for Roadivo's entitlement, the window
/// keeps its corner buttons.
@MainActor
final class CarPlayTabs: NSObject, CPTabBarTemplateDelegate {
    private let map: CPMapTemplate
    private weak var interface: CPInterfaceController?
    /// Cast chosen while the iPhone still casts brings its screen back.
    private let mirror: CarPlayMirror
    /// What this sets as the root; CarPlay's own `rootTemplate` is empty until the first.
    private weak var shownRoot: CPTemplate?
    private var bar: CPTabBarTemplate?
    private var home: CPListTemplate?
    private var cast: CPListTemplate?
    /// Its own tab with the bar; without it, the library stays under Home's recent picks.
    private let library: CPListTemplate

    init(map: CPMapTemplate, interface: CPInterfaceController, mirror: CarPlayMirror) {
        self.map = map
        self.interface = interface
        self.mirror = mirror
        library = CPListTemplate(title: String(appLocalized: "Library"), sections: [])
        library.emptyViewTitleVariants = [String(appLocalized: "Add a source on your iPhone")]
    }

    /// CarPlay sets how many tabs an app may show by its entitlements, so Roadivo asks rather than assumes.
    func install(home: CPListTemplate, favorites: CPListTemplate, cast: CPListTemplate, browser: CPListTemplate) {
        self.home = home
        self.cast = cast
        let tabs = [home, favorites, library, cast, browser]
        CarPlayTrace.write("tab bar allows \(CPTabBarTemplate.maximumTabCount) tabs")
        guard CPTabBarTemplate.maximumTabCount >= tabs.count else { return }
        // Titles alone, as in CarTV's bar.
        for tab in tabs {
            tab.tabTitle = tab.title
            tab.tabImage = nil
        }
        // Home holds only recent picks once the library has its own tab.
        home.emptyViewTitleVariants = [String(appLocalized: "Nothing here yet")]
        let bar = CPTabBarTemplate(templates: tabs)
        bar.delegate = self
        self.bar = bar
    }

    /// The tab bar on the home screen; the window for everything else. Coming back lands on Home, as CarTV's does.
    func show(home isHome: Bool) {
        guard let interface else { return }
        let target: CPTemplate = isHome ? bar ?? map : map
        guard shownRoot !== target else { return }
        shownRoot = target
        if let bar, let home, target === bar {
            bar.select(home)
        }
        CarPlayTrace.write("root: \(target === map ? "window" : "tabs")")
        interface.setRootTemplate(target, animated: false) { success, error in
            CarPlayTrace.write("root accepted: \(success)\(error.map { ", \($0.localizedDescription)" } ?? "")")
        }
    }

    /// Home's recent picks, and the library in its own tab; without the bar, both on Home.
    func fillHome(recent: [CPListItem], library groups: [CPListItem]) {
        let recent = CPListSection(items: recent, header: String(appLocalized: "Recent"), sectionIndexTitle: nil)
        guard bar != nil else {
            let groups = CPListSection(items: groups, header: String(appLocalized: "Library"), sectionIndexTitle: nil)
            home?.updateSections([recent, groups].filter { !$0.items.isEmpty })
            return
        }
        home?.updateSections(recent.items.isEmpty ? [] : [recent])
        library.updateSections([CPListSection(items: groups)])
    }

    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
        guard selectedTemplate === cast else { return }
        _ = mirror.reveal()
    }
}
