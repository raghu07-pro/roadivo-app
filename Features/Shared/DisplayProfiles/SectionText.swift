import SwiftUI

/// A list section's title in a theme font that grows with Dynamic Type: the list's own header font
/// failed the accessibility audit on these screens.
struct SectionHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(Typography.cardTitle)
            .foregroundStyle(.roadMuted)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A list section's footnote, in a theme font to match `SectionHeader`.
struct SectionFooter: View {
    let text: Text

    init(_ key: LocalizedStringKey) {
        text = Text(key)
    }

    var body: some View {
        text
            .font(Typography.caption)
            .foregroundStyle(.roadMuted)
    }
}
