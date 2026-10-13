import CarPlay
import OSLog

/// Roadivo on the CarPlay screen: Favorites, Recent and the library as
/// CarPlay lists, playback through the shared player, and the system Now
/// Playing screen. Video reaches the car display through AirPlay video, which
/// CarPlay allows only while parked and only in cars that support it; while
/// driving it plays sound only. Needs the CarPlay entitlement (DECISIONS 25).
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private let logger = Logger(subsystem: "com.roadivo", category: "CarPlay")

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        MainActor.assumeIsolated {
            self.interfaceController = interfaceController
            AppEnvironment.current?.carConnection.isCarPlayConnected = true
            interfaceController.setRootTemplate(rootTemplate(), animated: false) { [logger] _, error in
                if let error {
                    logger.error("Root template: \(error.localizedDescription, privacy: .public)")
                }
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
        }
    }

    // MARK: Templates

    @MainActor
    private func rootTemplate() -> CPTemplate {
        guard let environment = AppEnvironment.current else {
            return message("Open Roadivo on your iPhone to get started.")
        }
        guard environment.proAccess.isPro else {
            return message("Watching in the car is part of Roadivo Pro. Unlock it on your iPhone.")
        }
        let menu = CarPlayMenu.build(from: environment.repository)
        let favorites = list(String(appLocalized: "Favorites"), items: menu.favorites, symbol: "heart.fill")
        let recent = list(String(appLocalized: "Recent"), items: menu.recent, symbol: "clock.fill")
        let library = CPListTemplate(
            title: String(appLocalized: "Library"),
            sections: [CPListSection(items: menu.groups.map(groupRow))]
        )
        library.tabImage = UIImage(systemName: "play.square.stack.fill")
        library.emptyViewTitleVariants = [String(appLocalized: "Add a source on your iPhone")]
        return CPTabBarTemplate(templates: [favorites, recent, library])
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
}
