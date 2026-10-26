#if DEBUG
    import SwiftUI

    /// A key that lights up while pressed.
    struct CarKeyStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(.primary)
                .background(
                    configuration.isPressed ? Color.roadBrand.opacity(0.35) : Color.roadSurfaceElevated,
                    in: RoundedRectangle(cornerRadius: Radius.sm)
                )
                .contentShape(RoundedRectangle(cornerRadius: Radius.sm))
        }
    }
#endif
