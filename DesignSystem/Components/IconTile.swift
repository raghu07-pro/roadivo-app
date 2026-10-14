import SwiftUI

/// An SF Symbol on a rounded tile, as in iOS Settings: `.filled` is the brand gradient with a
/// light glyph, `.soft` a pale wash with an accent glyph.
struct IconTile: View {
    enum Style {
        case filled
        case soft
    }

    let systemImage: String
    var style: Style = .filled
    /// The tile's side at the default text size; it scales with Dynamic Type.
    var size: CGFloat = 30

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let side = size * min(scale, 1.6)
        let shape = RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
        Image(systemName: systemImage)
            .font(.system(size: side * 0.48, weight: .semibold))
            .foregroundStyle(style == .filled ? AnyShapeStyle(.roadOnBrand) : AnyShapeStyle(.roadAccent))
            .frame(width: side, height: side)
            .background {
                switch style {
                case .filled: shape.fill(.roadBrandGradient)
                case .soft: shape.fill(Color.roadBrand.opacity(0.14))
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview("Light") {
    HStack(spacing: Spacing.md) {
        IconTile(systemImage: "antenna.radiowaves.left.and.right")
        IconTile(systemImage: "paintpalette.fill", size: 46)
        IconTile(systemImage: "tv", style: .soft, size: 44)
    }
    .padding()
    .background(.roadCanvas)
}

#Preview("Dark, largest text") {
    HStack(spacing: Spacing.md) {
        IconTile(systemImage: "antenna.radiowaves.left.and.right")
        IconTile(systemImage: "tv", style: .soft, size: 44)
    }
    .padding()
    .background(.roadCanvas)
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}
