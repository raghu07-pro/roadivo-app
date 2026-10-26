#if DEBUG
    import SwiftUI

    /// A row on the car's lists, as Roadivo's cards on the iPhone (`cardStyle()`): the surface colour with a hairline
    /// edge on the canvas, washed in the theme's fill while pressed.
    struct CarCardStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            return configuration.label
                .foregroundStyle(.primary)
                .background(.roadSurface, in: shape)
                .overlay {
                    shape.fill(Color.roadBrand.opacity(configuration.isPressed ? 0.18 : 0))
                }
                .overlay { shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 1) }
                .contentShape(shape)
        }
    }
#endif
