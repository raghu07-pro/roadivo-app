#if DEBUG
    import SwiftUI

    /// Everything Roadivo draws on the plain CarPlay window over its video, road and the iPhone's screen
    /// (`CarPlayWindowController`): a page, or what the mode shows. The browser's page and toolbar are separate
    /// (`CarScreenController`), so taps reach the webpage.
    struct CarScreenView: View {
        let model: CarScreenModel

        var body: some View {
            content
                // Settings › Theme's accent and font style, as on the iPhone (`RootView`).
                .tint(.roadAccent)
                .fontDesign(AppTheme.shared.font.rootDesign)
        }

        @ViewBuilder private var content: some View {
            switch model.page {
            case let .search(search):
                CarSearchPage(model: model, search: search)
            case let .results(_, source):
                CarSearchResultsPage(model: model, source: source)
            case let .choices(title, options):
                CarChoicesPage(model: model, title: title, options: options)
            case .tabs:
                CarBrowserTabsPage(model: model)
            case .pageSize:
                CarBrowserPageSizePage(model: model)
            case nil:
                switch model.mode {
                case .tabs: CarScreenTabsView(model: model)
                case .player: CarScreenPlayerView(model: model)
                case .mirror: CarScreenMirrorView(model: model)
                case .upgrade: CarScreenNotice(model: model)
                // The page and its bar take their own taps.
                case .browser: Color.clear
                }
            }
        }
    }
#endif
