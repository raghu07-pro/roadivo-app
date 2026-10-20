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
                        SiteTile(site: site) { viewModel.open(site.url) }
                    }
                }
                Text("""
                Search or type a website. A page's videos can go to your car with AirPlay, and direct video \
                links play in Roadivo.
                """)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("browser.startPage")
    }
}

/// As many equal columns as fit `minimumWidth`, rows as tall as their tallest tile. Eager, unlike `LazyVGrid`, so
/// tiles keep their identity when larger text changes the column count (the audit reads a rebuilt tile as unscaled).
private struct TileGrid: Layout {
    let minimumWidth: CGFloat
    let spacing: CGFloat
    let rowSpacing: CGFloat

    private struct Row {
        var indices: [Int]
        var height: CGFloat
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? minimumWidth
        let rows = rows(of: subviews, width: width)
        let height = rows.reduce(0) { $0 + $1.height } + rowSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let width = columnWidth(in: bounds.width)
        var top = bounds.minY
        for row in rows(of: subviews, width: bounds.width) {
            for (column, index) in row.indices.enumerated() {
                let leading = bounds.minX + CGFloat(column) * (width + spacing)
                subviews[index].place(
                    at: CGPoint(x: leading, y: top),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: width, height: nil)
                )
            }
            top += row.height + rowSpacing
        }
    }

    private func columnCount(in width: CGFloat) -> Int {
        max(1, Int((width + spacing) / (minimumWidth + spacing)))
    }

    private func columnWidth(in width: CGFloat) -> CGFloat {
        let count = CGFloat(columnCount(in: width))
        return max(0, (width - spacing * (count - 1)) / count)
    }

    private func rows(of subviews: Subviews, width: CGFloat) -> [Row] {
        let count = columnCount(in: width)
        let proposal = ProposedViewSize(width: columnWidth(in: width), height: nil)
        return stride(from: 0, to: subviews.count, by: count).map { start in
            let indices = Array(start..<min(start + count, subviews.count))
            let height = indices.map { subviews[$0].sizeThatFits(proposal).height }.max() ?? 0
            return Row(indices: indices, height: height)
        }
    }
}

/// A site in the grid: its own icon, loaded from the site, and its initial until then or if it can't load.
private struct SiteTile: View {
    let site: BrowserSite
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 60

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                icon
                    .frame(width: min(iconSize, 84), height: min(iconSize, 84))
                Text(site.name)
                    .font(Typography.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(site.name))
        .accessibilityHint(Text("Opens this page"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("browser.site.\(site.name)")
    }

    private var icon: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        return shape
            .fill(.roadSurface)
            .overlay {
                AsyncImage(url: site.iconURL) { phase in
                    if let image = phase.image {
                        image.resizable().interpolation(.high).scaledToFit().padding(10)
                    } else {
                        initial
                    }
                }
            }
            .clipShape(shape)
            .overlay { shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1) }
            .accessibilityHidden(true)
    }

    private var initial: some View {
        ZStack {
            Palette.placeholderGradient(for: site.name)
            Text(String(site.name.prefix(1)))
                .font(Typography.sectionTitle)
                .foregroundStyle(.white)
        }
    }
}
