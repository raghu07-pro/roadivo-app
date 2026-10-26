#if DEBUG
    import SwiftUI

    /// A key on the car's keyboard, laid out as CarTV's and CarPlay's own in Roadivo's theme: letters on the surface
    /// colour, Shift, Delete and the page keys on the raised one, and the theme's fill while pressed.
    struct CarKeyCapStyle: ButtonStyle {
        enum Kind {
            case character
            case function
        }

        let kind: Kind

        func makeBody(configuration: Configuration) -> some View {
            let shape = RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            return configuration.label
                .foregroundStyle(.primary)
                .background(configuration.isPressed ? Color.roadBrand.opacity(0.35) : fill, in: shape)
                .shadow(color: .black.opacity(0.15), radius: 0, y: 1)
                .contentShape(shape)
        }

        private var fill: Color {
            switch kind {
            case .character: .roadSurface
            case .function: .roadSurfaceElevated
            }
        }
    }
#endif
