import CarPlay
import Observation
import OSLog

/// Roadivo on CarPlay: Favorites, Recent and Library lists, played through the shared player.
/// Video goes over AirPlay only while parked in supported cars (sound only when driving); DECISIONS 25.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    /// Filled in place, so a list or Now Playing the driver has open stays put.
    private var tabs: Tabs?
    private var isWatching = false
    private let logger = Logger(subsystem: "com.roadivo", category: "CarPlay")

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        MainActor.assumeIsolated {
            self.interfaceController = interfaceController
            AppEnvironment.current?.carConnection.isCarPlayConnected = true
            showRoot()
            if !isWatching {
                watchLibrary()
            }
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        MainActor.assumeIsolated {
            AppEnvironment.current?.carConnection.isCarPlayConnected = false
            self.interfaceController = nil
            tabs = nil
        }
    }

    // MARK: Updates

    /// Redraws after a purchase (Pro may still be loading at a cold start), a library change, or
    /// a new video (for Recent).
    @MainActor
    private func watchLibrary() {
        guard let environment = AppEnvironment.current else { return }
        isWatching = true
        withObservationTracking {
            _ = environment.proAccess.isPro
            _ = environment.router.libraryRevision
            _ = environment.playback.current?.id
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.libraryChanged() }
        }
    }

    @MainActor
    private func libraryChanged() {
        isWatching = false
        guard interfaceController != nil else { return }
        if (AppEnvironment.current?.proAccess.isPro ?? false) == (tabs != nil) {
            fillTabs()
        } else {
            showRoot()
        }
        watchLibrary()
    }

    // MARK: Templates

    @MainActor
    private func showRoot() {
        interfaceController?.setRootTemplate(rootTemplate(), animated: false) { [logger] _, error in
            if let error {
                logger.error("Root template: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @MainActor
    private func rootTemplate() -> CPTemplate {
        tabs = nil
        guard let environment = AppEnvironment.current else {
            return message(String(appLocalized: "Open Roadivo on your iPhone to get started."))
        }
        guard environment.proAccess.isPro else {
            return message(
                String(appLocalized: "Watching in the car is part of Roadivo Pro. Unlock it on your iPhone.")
            )
        }
        let favorites = list(String(appLocalized: "Favorites"), items: [], symbol: "heart.fill")
        let recent = list(String(appLocalized: "Recent"), items: [], symbol: "clock.fill")
        let library = list(String(appLocalized: "Library"), items: [], symbol: "play.square.stack.fill")
        library.emptyViewTitleVariants = [String(appLocalized: "Add a source on your iPhone")]
        tabs = Tabs(favorites: favorites, recent: recent, library: library)
        fillTabs()
        return CPTabBarTemplate(templates: [favorites, recent, library])
    }

    @MainActor
    private func fillTabs() {
        guard let tabs, let environment = AppEnvironment.current else { return }
        let menu = CarPlayMenu.build(from: environment.repository)
        tabs.favorites.updateSections([CPListSection(items: menu.favorites.map { row($0, queue: menu.favorites) })])
        tabs.recent.updateSections([CPListSection(items: menu.recent.map { row($0, queue: menu.recent) })])
        tabs.library.updateSections([CPListSection(items: menu.groups.map(groupRow))])
    }

    @MainActor
    private func list(_ title: String, items: [MediaItem], symbol: String) -> CPListTemplate {
        let template = CPListTemplate(
            title: title,
            sections: [CPListSection(items: items.map { row($0, queue: items) })]
        )
        template.tabImage = UIImage(systemName: symbol)
        template.emptyViewTitleVariants = [String(appLocalized: "Nothing here yet")]
        return template
    }

    @MainActor
    private func groupRow(_ group: CarPlayMenu.Group) -> CPListItem {
        let item = CPListItem(text: group.title, detailText: String(appLocalized: "\(group.items.count) items"))
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                guard let self else { return completion() }
                let template = self.list(group.title, items: group.items, symbol: "play.square.stack.fill")
                self.interfaceController?.pushTemplate(template, animated: true) { _, _ in completion() }
            }
        }
        return item
    }

    @MainActor
    private func row(_ media: MediaItem, queue: [MediaItem]) -> CPListItem {
        let item = CPListItem(
            text: media.title,
            detailText: media.groupTitle,
            image: UIImage(systemName: media.isLocalFile ? "film" : "play.tv")
        )
        if let progress = media.progress {
            item.playbackProgress = progress.fraction
        }
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                AppEnvironment.current?.playback.play(media, queue: queue)
                self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { _, _ in
                    completion()
                }
            }
        }
        return item
    }

    @MainActor
    private func message(_ text: String) -> CPTemplate {
        let template = CPListTemplate(title: "Roadivo", sections: [])
        template.emptyViewTitleVariants = [text]
        return template
    }

    private struct Tabs {
        let favorites: CPListTemplate
        let recent: CPListTemplate
        let library: CPListTemplate
    }
}
