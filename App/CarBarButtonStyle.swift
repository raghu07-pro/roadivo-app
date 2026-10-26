#if DEBUG
    import SwiftUI

    /// A button on the car browser's white bar, as in CarTV's: a light grey circle or capsule, darker while pressed.
    struct CarBarButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.5))
                .background(configuration.isPressed ? Color(.systemGray4) : Color(.systemGray6), in: Capsule())
                .contentShape(Capsule())
        }
    }
#endif
