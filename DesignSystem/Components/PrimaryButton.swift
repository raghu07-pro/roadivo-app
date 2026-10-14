import SwiftUI

/// The screen's one call to action: the theme gradient with a soft glow; the label is at least
/// 3:1 against both ends (large, bold text).
struct PrimaryButton: View {
    let title: Text
    var systemImage: String?
    var isLoading = false
    /// Hugs its label (empty states) instead of filling the width.
    var isCompact = false
    let action: () -> Void

    init(
        title: LocalizedStringKey,
        systemImage: String? = nil,
        isLoading: Bool = false,
        isCompact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(
            text: Text(title),
            systemImage: systemImage,
            isLoading: isLoading,
            isCompact: isCompact,
            action: action
        )
    }

    /// For a title built at runtime (a price), already localized.
    init(
        text: Text,
        systemImage: String? = nil,
        isLoading: Bool = false,
        isCompact: Bool = false,
        action: @escaping () -> Void
    ) {
        title = text
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isCompact = isCompact
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView().tint(.roadOnBrand)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                title
            }
            .font(Typography.button)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: isCompact ? nil : .infinity, minHeight: 54)
            .foregroundStyle(.roadOnBrand)
            .background(BrandFill())
            .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .disabled(isLoading)
    }
}

/// The primary-button look for labels that aren't a `PrimaryButton`
/// (a `Menu`'s label in an empty state).
struct BrandButtonLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(Typography.button)
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: 54)
            .foregroundStyle(.roadOnBrand)
            .background(BrandFill())
    }
}

/// The primary button's surface: the brand gradient, a faint top highlight
/// and a tinted shadow that lifts it off the page.
struct BrandFill: View {
    var cornerRadius: CGFloat = Radius.md

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(.roadBrandGradient)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            }
            .shadow(color: Color.roadBrandDeep.opacity(0.35), radius: 12, y: 6)
    }
}

/// For cards with a context menu: no press effect, because a dim or shrink under the system's
/// long-press lift made it stutter (and was captured in its snapshot).
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// Subtle press feedback; motion is dropped under Reduce Motion.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        PrimaryButton(title: "Add a Source", systemImage: "plus") {}
        PrimaryButton(title: "Adding…", isLoading: true) {}
        PrimaryButton(title: "Add a Source", systemImage: "plus", isCompact: true) {}
    }
    .padding()
    .background(.roadCanvas)
}
