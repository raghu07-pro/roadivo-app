import SwiftUI

/// The top of Home: the road at golden hour with the tagline and how much is
/// loaded, as mile-marker style data.
struct HomeHero: View {
    let channelCount: Int
    let groupCount: Int
    /// The one source Home is showing, if the user picked one.
    var sourceName: String?

    /// "Road Trip · 24 channels · 3 groups": pluralised, already-localized parts.
    private var summary: String {
        let counts = [String(appLocalized: "\(channelCount) channels"), String(appLocalized: "\(groupCount) groups")]
        return ([sourceName].compactMap(\.self) + counts).joined(separator: " · ")
    }

    @ScaledMetric(relativeTo: .largeTitle) private var height: CGFloat = 190
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// A floor, not a fixed height: large text grows the hero instead of being clipped. Landscape
    /// keeps it short so the channels stay in view.
    private var minHeight: CGFloat {
        let portrait = min(height, 320)
        return verticalSizeClass == .compact ? portrait * 0.6 : portrait
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(app: Brand.tagline)
                .font(Typography.screenTitle)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            Text(summary)
                .font(Typography.data)
                .textCase(.uppercase)
                .foregroundStyle(.roadAccent)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
        )
        // Always on the dark scene: the accent's bright variant.
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .bottom)
        .background { RoadScene(time: .goldenHour, horizon: 0.5) }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeHero(channelCount: 128, groupCount: 9).padding()
}

#Preview("Largest text, dark") {
    HomeHero(channelCount: 128, groupCount: 9)
        .padding()
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Landscape", traits: .landscapeLeft) {
    HomeHero(channelCount: 128, groupCount: 9).padding()
}
