import SwiftUI

/// One font style as a list row: "Aa", the name and a sample line, all in that style, with a check
/// on the chosen one (as on the Language screen).
struct FontStyleRow: View {
    let font: ThemeFont
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text("Aa")
                    .font(font.preview)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.roadAccent) : AnyShapeStyle(.primary))
                    .frame(width: 52, height: 44)
                    .background(.roadSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app: font.title)
                        .font(font.nameFont)
                        .foregroundStyle(.primary)
                    Text(app: Brand.tagline)
                        .font(font.sampleFont)
                        .foregroundStyle(.roadMuted)
                        .accessibilityHidden(true)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.roadAccent)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
            // Its own style, not the app-wide one, so each row previews itself.
            .fontDesign(font.design)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("theme.font.\(font.rawValue)")
    }
}
