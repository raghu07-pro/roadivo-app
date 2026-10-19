import SwiftUI

/// "How to Connect", from Settings and Discover › Cast to Screen: numbered steps for each way to the car, then what Pro
/// adds
/// and the safety note.
struct ConnectGuideView: View {
    let guide: ConnectGuide
    let isPro: Bool
    /// The section to open at: Discover's Cast to Screen opens at "mirroring".
    var focusedSection: String?

    var body: some View {
        ScrollViewReader { proxy in
            content
                .task {
                    if let focusedSection {
                        proxy.scrollTo(focusedSection, anchor: .top)
                    }
                }
        }
        .background(.roadCanvas)
        .clearsBottomAccessory()
        .navigationTitle("How to Connect")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("guide.screen")
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                ForEach(guide.sections) { section in
                    GuideSectionCard(section: section)
                        .id(section.id)
                }
                if !isPro {
                    Label {
                        Text(app: guide.proNote)
                    } icon: {
                        Image(systemName: "crown.fill").foregroundStyle(.roadAccent)
                    }
                    .font(Typography.secondary)
                    .accessibilityIdentifier("guide.pro")
                }
                Label {
                    Text("For passengers, or while parked. Never watch video while driving.")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.roadAccent)
                }
                .font(Typography.caption)
            }
            .padding(Spacing.md)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            IconTile(systemImage: guide.hasCarPlay ? "car.front.waves.up" : "car.fill", size: 52)
            Text(app: guide.title)
                .font(Typography.screenTitle)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(app: guide.subtitle)
                .font(Typography.body)
                .foregroundStyle(.roadMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One way to the car: its symbol and name, then its steps, numbered.
private struct GuideSectionCard: View {
    let section: ConnectGuide.Section

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                IconTile(systemImage: section.systemImage, style: .soft, size: 40)
                Text(app: section.title)
                    .font(Typography.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(Array(section.steps.enumerated()), id: \.offset) { index, step in
                GuideStep(number: index + 1, text: step)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide.\(section.id)")
    }
}

struct GuideStep: View {
    let number: Int
    let text: LocalizedStringResource

    @ScaledMetric(relativeTo: .subheadline) private var badge: CGFloat = 26

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(String(number))
                .font(Typography.cardTitle)
                .foregroundStyle(.roadOnBrand)
                .frame(width: badge, height: badge)
                .background(.roadBrandGradient, in: Circle())
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] * 0.7 }
            Text(app: text)
                .font(Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Step \(number)"))
        .accessibilityValue(Text(app: text))
    }
}

#Preview("Before CarPlay is granted") {
    NavigationStack { ConnectGuideView(guide: ConnectGuide(hasCarPlay: false), isPro: false) }
}

#Preview("With CarPlay, dark, large text") {
    NavigationStack { ConnectGuideView(guide: ConnectGuide(hasCarPlay: true), isPro: true) }
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility2)
}
