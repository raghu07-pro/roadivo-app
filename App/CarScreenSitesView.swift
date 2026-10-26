#if DEBUG
    import SwiftUI

    /// The Browser tab: search or an address, then every site's icon, which opens in the car's browser.
    struct CarScreenSitesView: View {
        let model: CarScreenModel

        var body: some View {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    Button {
                        model.actions?.showSearch(in: nil)
                    } label: {
                        Label {
                            Text(app: "Search or enter website")
                        } icon: {
                            Image(systemName: "magnifyingglass")
                        }
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Spacing.md)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    }
                    .buttonStyle(CarKeyStyle())
                    // The iPhone's start-page tiles: each icon fitted inside its square, never cropped.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Spacing.sm)], spacing: Spacing.md) {
                        ForEach(model.menu.sites) { site in
                            SiteTile(site: site, image: model.icons?.icon(for: site)) {
                                model.actions?.open(site.url)
                            }
                        }
                    }
                }
            }
        }
    }
#endif
