#if DEBUG
    import SwiftUI

    /// A key that lights up while pressed.
    struct CarKeyStyle: ButtonStyle {
        /// A circle or capsule, as CarTV's round buttons, instead of a rounded rectangle.
        var isRound = false

        func makeBody(configuration: Configuration) -> some View {
            let shape = isRound ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: Radius.sm))
            return configuration.label
                .foregroundStyle(.primary)
                .background(
                    configuration.isPressed ? Color.roadBrand.opacity(0.35) : Color.roadSurfaceElevated,
                    in: shape
                )
                .contentShape(shape)
        }
    }
#endif
