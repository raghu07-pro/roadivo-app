import SwiftUI

/// A numbered step on the theme's gradient, for the ? help sheets (`StepsHelp`).
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
