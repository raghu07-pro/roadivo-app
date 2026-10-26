#if DEBUG
    import SwiftUI

    extension View {
        /// The glass capsule CarPlay puts its tab bar and search field in.
        func carGlass() -> some View {
            carGlass(in: Capsule())
        }

        /// CarPlay's glass in `shape`: Liquid Glass from iOS 26, a light material before.
        @ViewBuilder
        func carGlass(in shape: some Shape) -> some View {
            if #available(iOS 26, *) {
                glassEffect(.regular, in: shape)
            } else {
                background(.ultraThinMaterial, in: shape)
                    .overlay(shape.stroke(.white.opacity(0.5), lineWidth: 1))
            }
        }
    }
#endif
