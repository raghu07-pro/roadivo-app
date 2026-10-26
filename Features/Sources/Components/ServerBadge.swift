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

/// One server type in Add a Source's list: its badge, name and a chevron to sign in.
struct ServerRow: View {
    let kind: MediaServerKind

    /// Where the rows' dividers start: past the badge, as iOS lists inset theirs.
    static let dividerInset: CGFloat = Spacing.md + 40 + Spacing.sm

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ServerBadge(kind: kind)
            Text(kind.title)
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#Preview("Light") {
    VStack(spacing: 0) {
        ForEach(MediaServerKind.allCases) { ServerRow(kind: $0) }
    }
    .cardStyle(padding: 0)
    .padding()
    .background(.roadCanvas)
}

#Preview("Dark, largest text") {
    VStack(spacing: 0) {
        ForEach(MediaServerKind.allCases) { ServerRow(kind: $0) }
    }
    .cardStyle(padding: 0)
    .padding()
    .background(.roadCanvas)
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}
