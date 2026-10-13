import SwiftUI

/// "Jellyfin", "Emby", "Xtream" buttons under "Or connect a media server".
struct ServerChip: View {
    let kind: MediaServerKind

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: kind.symbol)
                .foregroundStyle(Self.tint(kind))
                .accessibilityHidden(true)
            Text(kind.title)
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 52)
        .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    static func tint(_ kind: MediaServerKind) -> Color {
        switch kind {
        case .jellyfin: .purple
        case .emby: .green
        case .xtream: .indigo
        }
    }
}
