import SwiftUI

/// A video in the player's grid: the artwork and title, with the playing one outlined and its
/// title in the accent beside a moving waveform.
struct UpNextCard: View {
    let item: MediaItem
    let isCurrent: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ArtworkTile(
                    title: item.title,
                    imageURL: item.artworkURL,
                    videoURL: item.isLocalFile ? item.streamURL : nil
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(
                            isCurrent ? AnyShapeStyle(.roadBrandGradient) : AnyShapeStyle(Color.primary.opacity(0.08)),
                            lineWidth: isCurrent ? 2.5 : 1
                        )
                }
                HStack(spacing: Spacing.xs) {
                    Text(item.title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(isCurrent ? Color.roadAccent : Color.primary)
                        .lineLimit(1)
                    if isCurrent {
                        Image(systemName: "waveform")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.roadAccent)
                            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.title))
        .accessibilityValue(Text(item.groupTitle))
        .accessibilityHint(Text("Plays this channel"))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("upNext.\(item.title)")
    }
}
