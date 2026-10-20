import SwiftUI

/// Discover, laid out like CarTV's (owner, 2026-10-19; DECISIONS 122): only its three options. The Browser
/// on its own card, then Cast to Screen (Screen Broadcast to a car screen's browser, DECISIONS 124) and
/// Cast from an app. Car Mode stays one tap away on the player's car button (DECISIONS 102).
struct DiscoverView: View {
    let connection: CarConnection
    let isPro: Bool
    /// The Browser (DECISIONS 118); its page stays open between visits.
    let browser: BrowserViewModel
    let onPlayWebVideo: (MediaItem) -> Void
    /// Cast from an app › Your Videos: added to On this iPhone and played; a message if that failed.
    let onImportVideos: (_ urls: [URL], _ skipped: Int, _ isTemporary: Bool) async -> String?

    @State private var path: [Route] = []

    private enum Route: Hashable {
        case browser
        case castFromApp
        case castToScreen
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    optionsCard {
                        option(
                            title: "Browser",
                            detail: "Browse websites and watch their videos",
                            symbol: "globe",
                            identifier: "cast.browser"
                        ) { path.append(.browser) }
                    }
                    optionsCard {
                        option(
                            title: "Cast to Screen",
                            detail: "Mirror your iPhone screen",
                            symbol: "rectangle.on.rectangle",
                            identifier: "cast.mirroring"
                        ) { path.append(.castToScreen) }
                        Divider()
                            .padding(.leading, 56)
                        option(
                            title: "Cast from an app",
                            detail: "Apps with a built-in AirPlay button",
                            symbol: "arrow.up.forward.app",
                            identifier: "cast.fromApp"
                        ) { path.append(.castFromApp) }
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(.roadCanvas)
            .clearsBottomAccessory()
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            // The Browser's icons start arriving here, so they're usually in before it opens (DECISIONS 129).
            .task { await browser.icons.refresh(BrowserSite.all) }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .browser:
                    BrowserView(viewModel: browser, onPlay: onPlayWebVideo)
                case .castFromApp:
                    CastFromAppView(connection: connection, onImport: onImportVideos)
                case .castToScreen:
                    CastToScreenView(isPro: isPro)
                }
            }
        }
    }

    private func optionsCard(@ViewBuilder _ rows: () -> some View) -> some View {
        VStack(spacing: 0, content: rows)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity)
            .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private func option(
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        symbol: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                IconTile(systemImage: symbol, style: .soft, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
