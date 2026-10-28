import SwiftUI

/// The Browser before a page is open, laid out like CarTV's: a grid of sites, with the address bar at the
/// bottom where the open page keeps it. Nothing is kept: no bookmarks or Recent (owner, 2026-10-19).
struct BrowserStartPage: View {
    let viewModel: BrowserViewModel

    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 76

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                TileGrid(minimumWidth: tileWidth, spacing: Spacing.sm, rowSpacing: Spacing.lg) {
                    ForEach(BrowserSite.all) { site in
                        SiteTile(site: site, image: viewModel.icons.icon(for: site)) { viewModel.open(site.url) }
                    }
                }
                Text("""
                Search or type a website. A page's videos can go to your car with AirPlay, and direct video \
                links play in PlayCarTV.
                """)
                .font(Typography.caption)
                .foregroundStyle(.roadMuted)
            }
            .padding(Spacing.md)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        // The bar first, then the mini player's space, so the bar sits just above the mini player.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AddressField(viewModel: viewModel, isOnStartPage: true)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(.bar)
        }
        .clearsBottomAccessory()
        .task { await viewModel.icons.refresh(BrowserSite.all) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("browser.startPage")
    }
}
