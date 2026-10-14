import SwiftUI

/// Oversized round control for Car Mode: easy to hit on a mounted phone.
struct LargeControlButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var isProminent = false
    var isEnabled = true
    let action: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 76

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title.weight(.bold))
                .frame(width: size, height: size)
                .foregroundStyle(isProminent ? Color.roadOnBrand : Color.white)
                .background(
                    isProminent ? AnyShapeStyle(.roadBrandGradient) : AnyShapeStyle(.white.opacity(0.14)),
                    in: Circle()
                )
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(Text(label))
    }
}
