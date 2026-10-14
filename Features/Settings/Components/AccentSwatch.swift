import SwiftUI

/// One accent: its gradient in a circle, ringed and ticked when chosen, with the name beneath.
/// Drawn in its own colours, whatever the current theme.
struct AccentSwatch: View {
    let accent: ThemeAccent
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 46

    var body: some View {
        let colors = accent.colors
        let size = min(side, 76)
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [colors.brand, colors.brandDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .shadow(color: colors.brandDeep.opacity(isSelected ? 0.4 : 0), radius: 8, y: 4)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(colors.onBrand)
                            .transition(.scale.combined(with: .opacity))
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: size, height: size)
                .padding(4)
                .overlay {
                    Circle().strokeBorder(isSelected ? colors.brand : .clear, lineWidth: 2.5)
                }
                Text(app: accent.title)
                    .font(Typography.caption)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.roadMuted))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        // The label is the name beneath the circle.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("theme.accent.\(accent.rawValue)")
    }
}

#Preview("Light") {
    HStack {
        AccentSwatch(accent: .sunset, isSelected: true) {}
        AccentSwatch(accent: .ocean, isSelected: false) {}
        AccentSwatch(accent: .graphite, isSelected: false) {}
    }
    .padding()
    .background(.roadCanvas)
}

#Preview("Dark, largest text") {
    HStack {
        AccentSwatch(accent: .twilight, isSelected: true) {}
        AccentSwatch(accent: .graphite, isSelected: false) {}
    }
    .padding()
    .background(.roadCanvas)
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}
