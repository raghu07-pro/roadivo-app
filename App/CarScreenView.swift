#if DEBUG
    import SwiftUI

    /// Everything Roadivo draws on the plain CarPlay window over its video, road and the iPhone's screen
    /// (`CarPlayWindowController`): a page, or what the mode shows. The browser's page and toolbar are separate
    /// (`CarScreenController`), so taps reach the webpage.
    struct CarScreenView: View {
        let model: CarScreenModel

        var body: some View {
            switch model.page {
            case let .search(search):
                CarSearchPage(model: model, search: search)
            case let .choices(title, options):
                CarChoicesPage(model: model, title: title, options: options)
            case nil:
                switch model.mode {
                case .tabs: CarScreenTabsView(model: model)
                case .player: CarScreenPlayerView(model: model)
                case .mirror: CarScreenMirrorView(model: model)
                // The window's card shows through: the Pro line, or nothing over the browser.
                case .upgrade, .browser: Color.clear
                }
            }
        }
    }
#endif
