#if DEBUG
    import SwiftUI

    /// A key on the car's keyboard, as on CarPlay's own: letters on white (black at night), Shift, Delete and 123 on
    /// grey, and the search key in blue.
    struct CarKeyCapStyle: ButtonStyle {
        enum Kind {
            case character
            case function
            case submit
        }

        let kind: Kind

        func makeBody(configuration: Configuration) -> some View {
            let shape = RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            return configuration.label
                .foregroundStyle(kind == .submit ? Color.white : Color.primary)
                .background(fill.opacity(configuration.isPressed ? 0.6 : 1), in: shape)
                .shadow(color: .black.opacity(kind == .submit ? 0 : 0.15), radius: 0, y: 1)
                .contentShape(shape)
        }

        private var fill: Color {
            switch kind {
            case .character: Color(.systemBackground)
            case .function: Color(.systemGray3)
            case .submit: .blue
            }
        }
    }
#endif
