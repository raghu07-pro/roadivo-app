#if DEBUG
    import SwiftUI

    /// The browser's Start Page, which the Browser tab opens: every site's icon, then the pages saved with the star
    /// under Bookmarks; each opens in the current tab. The bar's address field above it searches (owner, 2026-10-26).
    struct CarScreenSitesView: View {
        let model: CarScreenModel

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    // The iPhone's start-page tiles: each icon fitted inside its square, never cropped.
                    grid(model.menu.sites)
                    // Pages saved with the browser's star, below the sites, as icons like theirs (owner, 2026-10-26).
                    if !model.savedPages.isEmpty {
                        Text(app: "Bookmarks")
                            .font(.headline)
                            .padding(.top, Spacing.sm)
                        grid(model.savedPages.map(\.site))
                    }
                }
            }
        }

        private func grid(_ sites: [BrowserSite]) -> some View {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Spacing.sm)], spacing: Spacing.md) {
                ForEach(sites, id: \.url) { site in
                    SiteTile(site: site, image: model.icons?.icon(for: site)) {
                        model.actions?.open(site.url)
                    }
                }
            }
        }
    }
#endif
