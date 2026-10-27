import SwiftUI

/// Before a place is chosen: Roadivo's road at the hour's light, as on the splash and the app's icon, asking where to
/// (owner, 2026-10-27; DECISIONS 172).
struct WhereToCard: View {
    /// The hour's light, which the app works out (`SplashMoment`).
    let time: RoadScene.TimeOfDay

    @ScaledMetric(relativeTo: .title3) private var side: CGFloat = 64

    var body: some View {
        HStack(spacing: Spacing.md) {
            RoadScene(time: time, animated: false, sunIsPlayButton: true)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: side * 0.24, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Where to?")
                    .font(Typography.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("Search for a place to see the route from where you are.")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack {
        WhereToCard(time: .goldenHour)
        WhereToCard(time: .night)
            .environment(\.dynamicTypeSize, .accessibility2)
    }
    .padding()
    .background(.roadCanvas)
}
