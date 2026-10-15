import SwiftUI

/// Settings › Theme: Light / Dark / System, the accent colours and the font style. Every
/// choice applies to the whole app straight away, this screen included.
struct ThemeView: View {
    let viewModel: ThemeViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var swatchColumn: CGFloat = 92

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                section(title: "Appearance", footer: "System follows your iPhone's Light or Dark Mode setting.") {
                    appearancePicker
                }
                section(title: "Accent Color", footer: nil) {
                    accentPicker
                }
                section(
                    title: "Font Style",
                    footer: "Changes the lettering across the app. Text still follows your iPhone's text size."
                ) {
                    fontPicker
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(.roadCanvas)
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appearancePicker: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(spacing: Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.sm))
        return layout {
            ForEach(viewModel.appearances) { appearance in
                AppearanceOption(
                    appearance: appearance,
                    isSelected: viewModel.appearance == appearance,
                    isRow: isLarge
                ) {
                    viewModel.choose(appearance)
                }
            }
        }
    }

    private var accentPicker: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: min(swatchColumn, 220)), spacing: Spacing.xs, alignment: .top)],
            spacing: Spacing.xs
        ) {
            ForEach(viewModel.accents) { accent in
                AccentSwatch(accent: accent, isSelected: viewModel.accent == accent) {
                    // A short cross-fade as the whole app re-tints.
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        viewModel.choose(accent)
                    }
                }
            }
        }
        .padding(Spacing.sm)
        .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    /// A list in one card, each row in its own lettering.
    private var fontPicker: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.fonts) { font in
                if font != viewModel.fonts.first {
                    Divider().padding(.leading, Spacing.md + 52 + Spacing.sm)
                }
                FontStyleRow(font: font, isSelected: viewModel.font == font) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        viewModel.choose(font)
                    }
                }
            }
        }
        .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private func section(
        title: LocalizedStringKey,
        footer: LocalizedStringKey?,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
                .padding(.horizontal, Spacing.xxs)
                .accessibilityAddTraits(.isHeader)
            content()
            if let footer {
                Text(footer)
                    .font(Typography.caption)
                    .foregroundStyle(.roadMuted)
                    .padding(.horizontal, Spacing.xxs)
            }
        }
    }
}

#Preview("Light") {
    NavigationStack { ThemeView(viewModel: ThemeViewModel()) }
}

#Preview("Dark") {
    NavigationStack { ThemeView(viewModel: ThemeViewModel()) }
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    NavigationStack { ThemeView(viewModel: ThemeViewModel()) }
        .environment(\.dynamicTypeSize, .accessibility3)
}
