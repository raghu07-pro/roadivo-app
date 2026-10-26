#if DEBUG
    import SwiftUI

    /// The car browser's bar along the top, as CarTV's: Close back to the Browser tab, Back and Forward, the page's
    /// address, which opens the search page, Reload, and Full screen, which hides the bar (DECISIONS 163).
    struct CarScreenBrowserBar: View {
        let model: CarScreenModel

        var body: some View {
            HStack(spacing: Spacing.xs) {
                tool("xmark", label: "Close") { $0.closeBrowser() }
                tool("chevron.backward", label: "Back", enabled: model.canGoBack) { $0.browserBack() }
                tool("chevron.forward", label: "Forward", enabled: model.canGoForward) { $0.browserForward() }
                address
                tool("arrow.clockwise", label: "Reload") { $0.browserReload() }
                tool("arrow.up.left.and.arrow.down.right", label: "Full screen") { $0.setBrowserFullScreen(true) }
            }
            .padding(Spacing.xs)
            .background(Color.roadCanvas.ignoresSafeArea())
        }

        /// The page's site, as in CarTV's bar; a tap searches or opens another address.
        private var address: some View {
            Button {
                model.actions?.showSearch(in: model.pageURL)
            } label: {
                Group {
                    if let page = model.pageURL {
                        Text(WebAddress.displayName(of: page))
                    } else {
                        Text(app: "Search or enter website")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.title3)
                .lineLimit(1)
                .padding(.horizontal, Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(CarKeyStyle())
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
                    .font(.title2)
                    .frame(width: 56, height: 52)
            }
            .buttonStyle(CarKeyStyle())
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.4)
            .accessibilityLabel(Text(app: label))
        }
    }
#endif
