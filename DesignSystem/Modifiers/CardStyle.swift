import SwiftUI

struct CardStyle: ViewModifier {
    var padding: CGFloat = Spacing.md

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        content
            .padding(padding)
            .background(.roadSurface, in: shape)
            // A hairline edge, so white cards hold their shape on the light canvas.
            .overlay { shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 1) }
    }
}

extension View {
    func cardStyle(padding: CGFloat = Spacing.md) -> some View {
        modifier(CardStyle(padding: padding))
    }
}
