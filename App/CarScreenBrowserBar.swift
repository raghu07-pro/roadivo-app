#if DEBUG
    import SwiftUI

    /// The car browser's white bar along the top, as CarTV's (DECISIONS 163): Close, Back, Forward, split view and
    /// Start Page;
    /// the page's address, which opens the search page; then Reload, Tabs, the star that saves the page, Full screen,
    /// and Page size. The options are the CarPlay browser's More menu.
    struct CarScreenBrowserBar: View {
        let model: CarScreenModel

        var body: some View {
            HStack(spacing: Spacing.xs) {
                tool("xmark", label: "Close") { $0.closeBrowser() }
                tool("chevron.backward", label: "Back", enabled: model.canGoBack) { $0.browserBack() }
                tool("chevron.forward", label: "Forward", enabled: model.canGoForward) { $0.browserForward() }
                // The iPhone's screen beside the page, as CarTV's split view.
                tool(model.isSplit ? "rectangle.split.2x1.fill" : "rectangle.split.2x1", label: "Cast") {
                    $0.toggleSplit()
                }
                tool("house", label: "Start Page") { $0.showStartPage() }
                address
                tool("arrow.clockwise", label: "Reload") { $0.browserReload() }
                // The open tabs' count, as in CarTV's bar.
                tool("\(min(model.tabs.count, 50)).square", label: "Tabs") { $0.showTabs() }
                tool(
                    model.isPageSaved ? "star.fill" : "star",
                    label: model.isPageSaved ? "Remove saved page" : "Save this page",
                    enabled: model.pageURL != nil
                ) { $0.toggleSavedPage() }
                tool("arrow.up.left.and.arrow.down.right", label: "Full screen") { $0.setBrowserFullScreen(true) }
                tool("textformat.size", label: "Page size") { $0.showPageSize() }
            }
            // A slim bar, as CarTV's: 34-point buttons in 40 points (owner, 2026-10-26).
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 3)
            .background(Color(.systemBackground).ignoresSafeArea())
        }

        /// The page's site, as in CarTV's bar; a tap searches or opens another address.
        private var address: some View {
            Button {
                model.actions?.showSearch(in: model.pageURL)
            } label: {
                Group {
                    if let page = model.pageURL, !model.showsStartPage {
                        Text(WebAddress.displayName(of: page))
                    } else {
                        Text(app: "Search or enter website")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.body)
                .lineLimit(1)
                .padding(.horizontal, Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(CarBarButtonStyle())
            .accessibilityHint(Text(app: "Search or enter website"))
        }

        private func tool(
            _ symbol: String,
            label: LocalizedStringResource,
            enabled: Bool = true,
            action: @escaping (CarScreenActions) -> Void
        ) -> some View {
            Button {
                if let actions = model.actions {
                    action(actions)
                }
            } label: {
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 44, height: 34)
            }
            .buttonStyle(CarBarButtonStyle())
            .disabled(!enabled)
            .accessibilityLabel(Text(app: label))
        }
    }
#endif
