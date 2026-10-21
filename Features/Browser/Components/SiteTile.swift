import SwiftUI

/// A site: its icon, kept on the iPhone (DECISIONS 129), or its initial until the icon first arrives. On the
/// Browser's start page and Discover's Browser card.
struct SiteTile: View {
    let site: BrowserSite
    let image: UIImage?
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
                if let image {
                    Image(uiImage: image).resizable().interpolation(.high).scaledToFit().padding(10)
                } else {
                    initial
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
