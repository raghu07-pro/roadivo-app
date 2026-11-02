#if DEBUG
    import SwiftUI

    /// A button on the car browser's bar: PlayCarTV's surface in a circle or capsule on the canvas, as the car's cards
    /// (`CarCardStyle`), washed in the theme's fill while pressed.
    struct CarBarButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(isEnabled ? Color.primary : Color.roadMuted.opacity(0.5))
                .background(.roadSurface, in: Capsule())
                .overlay { Capsule().fill(Color.roadBrand.opacity(configuration.isPressed ? 0.18 : 0)) }
                .overlay { Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 1) }
                .contentShape(Capsule())
        }
    }
#endif
