import SwiftUI

/// A shelf's header on Home: the title, with its count at the end, in the accent with a chevron when it opens the
/// group ("17 channels ›", as App Store's See All), otherwise quiet grey. Large text puts the count under the title.
struct ShelfHeader: View {
    let title: String
    /// Empty for a shelf whose count says nothing useful (Continue Watching's films aren't "channels").
    var detail = ""
    var opensGroup = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    titleText
                    if !detail.isEmpty {
                        count
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    titleText.layoutPriority(1)
                    Spacer(minLength: Spacing.sm)
                    if !detail.isEmpty {
                        count.fixedSize()
                    }
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
        .foregroundStyle(opensGroup ? AnyShapeStyle(.roadAccent) : AnyShapeStyle(.roadMuted))
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
