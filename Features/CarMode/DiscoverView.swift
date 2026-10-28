import SwiftUI

/// Discover (DECISIONS 122, 135–136): two cards, the Browser with its first sites one tap away, and Cast to Screen
/// (Screen Broadcast to a car screen's browser, DECISIONS 124). Car Mode stays on the player's car button (DECISIONS
/// 102).
struct DiscoverView: View {
    let isPro: Bool
    /// The Browser (DECISIONS 118); its page stays open between visits.
    let browser: BrowserViewModel
    let onPlayWebVideo: (MediaItem) -> Void
    /// A site picked on the CarPlay screen; opened in the Browser, then cleared (DECISIONS 131).
    @Binding var browserRequest: URL?
    /// CarPlay is on, and whether PlayCarTV on the car's screen shows this iPhone, for Cast to Screen.
    var isCarConnected = false
    var isCarShowing = false

    @State private var path: [Route] = []
    /// A little narrower than the start page's, so the card's four sites share one row on every iPhone; larger text
    /// widens them until they wrap.
    @ScaledMetric(relativeTo: .body) private var siteColumn: CGFloat = 68

    private enum Route: Hashable {
        case browser
        case castToScreen
    }

    /// The Browser's first sites, as quick links on its card.
    private let quickSites = Array(BrowserSite.all.prefix(4))

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Side by side where there's room (landscape), else one above the other.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: Spacing.md) {
                            browserCard.frame(minWidth: 320)
                            castCard.frame(minWidth: 320)
                        }
                        VStack(spacing: Spacing.md) {
                            browserCard
                            castCard
                        }
                    }
                    safetyNote
                }
                .padding(Spacing.md)
                .frame(maxWidth: 900)
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
                case .castToScreen:
                    CastToScreenView(isCarConnected: isCarConnected, isCarShowing: isCarShowing)
                }
            }
        }
        // Initial too: a site picked in the car before this tab was first shown still opens.
        .onChange(of: browserRequest, initial: true) { _, url in
            guard let url else { return }
            browserRequest = nil
            open(url)
        }
    }

    // MARK: Cards

    private var browserCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            cardHeader(
                title: "Browser",
                detail: "Browse websites and watch their videos",
                symbol: "globe",
                identifier: "cast.browser"
            ) { path.append(.browser) }
            // The start page's eager grid: the text-size audit reads a tile LazyVGrid rebuilds as unscaled.
            TileGrid(minimumWidth: siteColumn, spacing: Spacing.xs, rowSpacing: Spacing.md) {
                ForEach(quickSites) { site in
                    SiteTile(site: site, image: browser.icons.icon(for: site)) { open(site.url) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var castCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            cardHeader(
                title: "Cast to Screen",
                detail: "Mirror your iPhone screen",
                symbol: "rectangle.on.rectangle",
                identifier: "cast.mirroring"
            ) { path.append(.castToScreen) }
            CastPicture()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var safetyNote: some View {
        Label {
            Text("For passengers, or while parked. Never watch video while driving.")
                .foregroundStyle(.roadMuted)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.roadAccent)
        }
        .font(Typography.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The card's title row; the whole row opens the option.
    private func cardHeader(
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        symbol: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                IconTile(systemImage: symbol, style: .filled, size: 56)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(Typography.sectionTitle)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(Typography.secondary)
                        .foregroundStyle(.roadMuted)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func open(_ url: URL) {
        browser.open(url)
        path = [.browser]
    }
}

/// What Cast to Screen does, drawn: the iPhone's screen going to the car's. Decorative.
private struct CastPicture: View {
    var body: some View {
        HStack(spacing: Spacing.lg) {
            Image(systemName: "iphone")
            Image(systemName: "dot.radiowaves.right")
                .foregroundStyle(.roadAccent)
            Image(systemName: "car.side")
        }
        .font(.largeTitle)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(.roadCanvas, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityHidden(true)
    }
}

#Preview("Discover") {
    DiscoverView(isPro: false, browser: BrowserViewModel(), onPlayWebVideo: { _ in }, browserRequest: .constant(nil))
}

#Preview("Discover, dark, large text") {
    DiscoverView(isPro: true, browser: BrowserViewModel(), onPlayWebVideo: { _ in }, browserRequest: .constant(nil))
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility2)
}
