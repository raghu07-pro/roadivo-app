import SwiftUI

/// The top of Home: the road at golden hour with the tagline and how much is
/// loaded, as mile-marker style data.
struct HomeHero: View {
    let channelCount: Int
    let groupCount: Int

    /// "24 channels · 3 groups": two pluralised, already-localized parts.
    private var summary: String {
        String(appLocalized: "\(channelCount) channels") + " · " + String(appLocalized: "\(groupCount) groups")
    }

    @ScaledMetric(relativeTo: .largeTitle) private var height: CGFloat = 190

    var body: some View {
        RoadScene(time: .goldenHour, horizon: 0.5)
            .frame(height: min(height, 320))
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(app: Brand.tagline)
                        .font(Typography.screenTitle)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                    Text(summary)
                        .font(Typography.data)
                        .textCase(.uppercase)
                        .foregroundStyle(.roadLane)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeHero(channelCount: 128, groupCount: 9).padding()
}
