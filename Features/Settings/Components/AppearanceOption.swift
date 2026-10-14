import SwiftUI

/// One of Light / Dark / System: a miniature of the app in that appearance
/// (System is split down the middle), with a radio mark and the name.
/// `isRow` lays it out sideways for the accessibility text sizes.
struct AppearanceOption: View {
    let appearance: ThemeAppearance
    let isSelected: Bool
    var isRow = false
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        Button(action: action) {
            Group {
                if isRow {
                    HStack(spacing: Spacing.md) {
                        MiniScreen(appearance: appearance).frame(width: 64, height: 88)
                        caption
                        Spacer(minLength: 0)
                    }
                } else {
                    VStack(spacing: Spacing.sm) {
                        MiniScreen(appearance: appearance)
                            .aspectRatio(0.72, contentMode: .fit)
                            .frame(maxWidth: 120)
                        caption
                    }
                }
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(.roadSurface, in: shape)
            .overlay {
                shape.strokeBorder(
                    isSelected ? AnyShapeStyle(.roadBrandGradient) : AnyShapeStyle(Color.primary.opacity(0.06)),
                    lineWidth: isSelected ? 2 : 1
                )
            }
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        // The label is the name under the miniature (which VoiceOver skips).
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("theme.appearance.\(appearance.rawValue)")
    }

    private var caption: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? AnyShapeStyle(.roadAccent) : AnyShapeStyle(.tertiary))
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
            Text(app: appearance.title)
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }
}

/// The app in miniature, in one appearance or (System) both side by side.
private struct MiniScreen: View {
    let appearance: ThemeAppearance

    var body: some View {
        Group {
            switch appearance {
            case .light:
                MiniApp().environment(\.colorScheme, .light)
            case .dark:
                MiniApp().environment(\.colorScheme, .dark)
            case .system:
                ZStack {
                    MiniApp().environment(\.colorScheme, .light)
                    MiniApp()
                        .environment(\.colorScheme, .dark)
                        .mask {
                            HStack(spacing: 0) {
                                Color.clear
                                Color.black
                            }
                        }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

/// A title, a card with a section marker and two tiles, and the main button.
private struct MiniApp: View {
    var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.width
            VStack(alignment: .leading, spacing: unit * 0.07) {
                Capsule()
                    .fill(.primary.opacity(0.85))
                    .frame(width: unit * 0.45, height: unit * 0.07)
                VStack(alignment: .leading, spacing: unit * 0.05) {
                    HStack(spacing: unit * 0.04) {
                        Capsule()
                            .fill(.roadBrandGradient)
                            .frame(width: unit * 0.035, height: unit * 0.11)
                        Capsule()
                            .fill(.primary.opacity(0.3))
                            .frame(width: unit * 0.36, height: unit * 0.05)
                    }
                    HStack(spacing: unit * 0.04) {
                        RoundedRectangle(cornerRadius: unit * 0.04, style: .continuous)
                            .fill(Palette.placeholderGradient(for: "Coastal Echoes"))
                        RoundedRectangle(cornerRadius: unit * 0.04, style: .continuous)
                            .fill(Palette.placeholderGradient(for: "Highway Stop"))
                    }
                    .frame(height: unit * 0.22)
                }
                .padding(unit * 0.06)
                .background(.roadSurface, in: RoundedRectangle(cornerRadius: unit * 0.07, style: .continuous))
                Spacer(minLength: 0)
                Capsule()
                    .fill(.roadBrandGradient)
                    .frame(height: unit * 0.12)
            }
            .padding(unit * 0.08)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .background(.roadCanvas)
        }
    }
}

#Preview("Light") {
    HStack(alignment: .top, spacing: Spacing.sm) {
        ForEach(ThemeAppearance.allCases) { appearance in
            AppearanceOption(appearance: appearance, isSelected: appearance == .system) {}
        }
    }
    .padding()
    .background(.roadCanvas)
}

#Preview("Dark, largest text") {
    VStack(spacing: Spacing.sm) {
        ForEach(ThemeAppearance.allCases) { appearance in
            AppearanceOption(appearance: appearance, isSelected: appearance == .dark, isRow: true) {}
        }
    }
    .padding()
    .background(.roadCanvas)
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}
