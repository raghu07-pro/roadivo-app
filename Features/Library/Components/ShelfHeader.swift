import SwiftUI

/// A shelf's header on Home: the title, with its count at the end ("17 channels ›" when it opens
/// the group), in quiet grey. Large text puts the count under the title.
struct ShelfHeader: View {
    let title: String
    let detail: String
    var opensGroup = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    titleText
                    count
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    titleText.layoutPriority(1)
                    Spacer(minLength: Spacing.sm)
                    count.fixedSize()
                }
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var titleText: some View {
        Text(title)
            .font(Typography.sectionTitle)
            .foregroundStyle(.primary)
            .lineLimit(2)
    }

    private var count: some View {
        HStack(spacing: Spacing.xxs) {
            Text(detail)
            if opensGroup {
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .fontWeight(.semibold)
                    .accessibilityHidden(true)
            }
        }
        .font(Typography.secondary)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        ShelfHeader(title: "Continue Watching", detail: "3 channels")
        ShelfHeader(title: "Movies", detail: "11 items", opensGroup: true)
        ShelfHeader(title: "Entertainment and Lifestyle", detail: "214 channels", opensGroup: true)
    }
    .padding()
    .background(.roadCanvas)
}

#Preview("Dark, largest text") {
    ShelfHeader(title: "Interviews", detail: "3 channels", opensGroup: true)
        .padding()
        .background(.roadCanvas)
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility5)
}
