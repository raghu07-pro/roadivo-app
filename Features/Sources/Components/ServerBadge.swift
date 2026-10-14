import SwiftUI

/// A media server's mark: its symbol on a tile in the service's own colours (Plex's amber
/// chevron on charcoal), so each is recognisable whatever the app's theme.
struct ServerBadge: View {
    let kind: MediaServerKind
    var size: CGFloat = 40

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let side = size * min(scale, 1.5)
        Image(systemName: kind.symbol)
            .font(.system(size: side * 0.46, weight: .bold))
            .foregroundStyle(glyph)
            .frame(width: side, height: side)
            .background(fill, in: RoundedRectangle(cornerRadius: side * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }

    private var fill: LinearGradient {
        let colors: [Color] = switch kind {
        case .jellyfin: [.purple, .blue]
        case .emby: [Color(red: 0.32, green: 0.71, blue: 0.29), Color(red: 0.20, green: 0.55, blue: 0.20)]
        case .xtream: [.indigo, Color(red: 0.22, green: 0.20, blue: 0.64)]
        case .plex: [Color(red: 0.16, green: 0.16, blue: 0.17), Color(red: 0.09, green: 0.09, blue: 0.10)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var glyph: Color {
        kind == .plex ? Color(red: 0.90, green: 0.63, blue: 0.05) : .white
    }
}

/// One server type under "Or connect a media server": its badge, name and what signing in takes.
struct ServerCard: View {
    let kind: MediaServerKind

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        HStack(spacing: Spacing.sm) {
            ServerBadge(kind: kind)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(app: kind.subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(.roadMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(.roadSurface, in: shape)
        .overlay { shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 1) }
        .contentShape(shape)
    }
}

#Preview("Light") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
        ForEach(MediaServerKind.allCases) { ServerCard(kind: $0) }
    }
    .padding()
    .background(.roadCanvas)
}

#Preview("Dark, largest text") {
    VStack {
        ForEach(MediaServerKind.allCases) { ServerCard(kind: $0) }
    }
    .padding()
    .background(.roadCanvas)
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}
