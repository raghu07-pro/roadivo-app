import SwiftUI

struct UpNextRow: View {
    let item: MediaItem
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                ArtworkTile(
                    title: item.title,
                    imageURL: item.artworkURL,
                    videoURL: item.isLocalFile ? item.streamURL : nil,
                    cornerRadius: Radius.sm
                )
                .frame(width: 112)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(isCurrent ? Color.roadAccent : Color.primary)
                        .lineLimit(2)
                    Text(item.groupTitle).font(Typography.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isCurrent {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                        .foregroundStyle(.roadAccent)
                        .accessibilityHidden(true)
                }
            }
            .padding(Spacing.xs)
            .background(
                isCurrent ? AnyShapeStyle(.roadAccent.opacity(0.12)) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
