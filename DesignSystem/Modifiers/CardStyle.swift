import SwiftUI

struct CardStyle: ViewModifier {
    var padding: CGFloat = Spacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

extension View {
    func cardStyle(padding: CGFloat = Spacing.md) -> some View {
        modifier(CardStyle(padding: padding))
    }
}
