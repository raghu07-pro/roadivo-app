#if DEBUG
    import SwiftUI

    /// A control over a video or the road: dark glass, so it reads on any picture.
    struct CarControlStyle: ButtonStyle {
        enum Shape {
            case capsule
            case circle
        }

        var shape = Shape.capsule

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(.white)
                .background(.black.opacity(configuration.isPressed ? 0.75 : 0.55), in: backing)
                .contentShape(backing)
        }

        private var backing: AnyShape {
            shape == .circle ? AnyShape(Circle()) : AnyShape(Capsule())
        }
    }
#endif
