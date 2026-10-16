import SwiftUI

/// Oversized round control for Car Mode: easy to hit on a mounted phone.
struct LargeControlButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var isProminent = false
    var isEnabled = true
    /// A wide capsule, for the one button that matters most (Car Mode's Drive View play).
    var isWide = false
    let action: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var scaledSize: CGFloat = 76

    /// Grows with Dynamic Type up to a point, so three still fit across a landscape iPhone.
    private var size: CGFloat {
        min(scaledSize, 96)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title.weight(.bold))
                // The wide one narrows before anything is pushed off the screen.
                .frame(minWidth: size, idealWidth: isWide ? size * 2.2 : size, maxWidth: isWide ? size * 2.2 : size)
                .frame(height: size)
                .foregroundStyle(isProminent ? Color.roadOnBrand : Color.white)
                .background(
                    isProminent ? AnyShapeStyle(.roadBrandGradient) : AnyShapeStyle(.white.opacity(0.14)),
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(Text(label))
    }
}
