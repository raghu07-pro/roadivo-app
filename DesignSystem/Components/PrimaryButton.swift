import SwiftUI

/// The one call to action on a screen: a lane-yellow road-sign panel with
/// asphalt lettering (about 12:1 contrast in both appearances).
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
                    ProgressView().tint(.roadAsphalt)
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
            .foregroundStyle(.roadAsphalt)
            .background(.roadLane, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
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
            .foregroundStyle(.roadAsphalt)
            .background(.roadLane, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
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
