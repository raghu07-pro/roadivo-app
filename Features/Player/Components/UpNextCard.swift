import SwiftUI

/// A video in the player's grid: the artwork and title, with the playing one outlined, a moving waveform on its
/// picture and its title in the accent, using the card's full width.
struct UpNextCard: View {
    let item: MediaItem
    let isCurrent: Bool
    /// A poster cropped to 16:9, in a grid that mixes posters with wide cards.
    var isWide = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ArtworkTile(item: item, isWide: isWide)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(
                                isCurrent ? AnyShapeStyle(.roadBrandGradient) :
                                    AnyShapeStyle(Color.primary.opacity(0.08)),
                                lineWidth: isCurrent ? 2.5 : 1
                            )
                    }
                    .overlay(alignment: .bottomLeading) {
                        // On the picture, as Home's heart, so the title keeps the card's width.
                        if isCurrent {
                            Image(systemName: "waveform")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
                                .padding(6)
                                .background(.black.opacity(0.45), in: Capsule())
                                .padding(Spacing.xs)
                        }
                    }
                // Two lines, as Home's cards: one cut long titles off at larger text sizes.
                Text(item.title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(isCurrent ? Color.roadAccent : Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
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
