import SwiftUI

/// A horizontally scrolling row of cards for one group.
struct ChannelCarousel: View {
    let items: [MediaItem]
    let onPlay: (MediaItem) -> Void
    let onToggleFavorite: (MediaItem) -> Void
    var onDelete: ((MediaItem) -> Void)?
    /// Continue Watching's actions, offered only on its own row.
    var onPlayFromBeginning: ((MediaItem) -> Void)?
    var onRemoveFromHistory: ((MediaItem) -> Void)?

    @ScaledMetric(relativeTo: .subheadline) private var cardWidth: CGFloat = 176

    var body: some View {
        let isWide = items.mixesArtworkShapes
        ScrollView(.horizontal, showsIndicators: false) {
            // Not lazy: a lazy row takes its height from its first card, which squeezed a taller
            // card's artwork (a poster, or a card with "… left"). Rows hold at most 20 cards.
            HStack(alignment: .top, spacing: Spacing.sm) {
                ForEach(items) { item in
                    ChannelCard(
                        item: item,
                        onPlay: { onPlay(item) },
                        onToggleFavorite: { onToggleFavorite(item) },
                        onDelete: item.deleteAction(onDelete),
                        onPlayFromBeginning: onPlayFromBeginning.map { action in { action(item) } },
                        onRemoveFromHistory: onRemoveFromHistory.map { action in { action(item) } },
                        isWide: isWide
                    )
                    // Posters stand tall, as on a streaming shelf.
                    .frame(width: item.artwork == .poster && !isWide ? min(cardWidth * 0.86, 240) : min(cardWidth, 300))
                }
            }
            .padding(.horizontal, Spacing.md)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }
}

extension [MediaItem] {
    /// Posters beside wide cards (a channel next to a film): every card is then drawn wide, the poster
    /// cropped to fill it, so a row or grid lines up (DECISIONS 108).
    var mixesArtworkShapes: Bool {
        contains { $0.artwork == .poster } && contains { $0.artwork != .poster }
    }
}

extension MediaItem {
    /// Videos on this iPhone can be deleted; streams are managed per source.
    func deleteAction(_ onDelete: ((MediaItem) -> Void)?) -> (() -> Void)? {
        guard isLocalFile, let onDelete else { return nil }
        return { onDelete(self) }
    }
}

/// An adaptive grid of cards, for a group's screen, Favorites, On this iPhone and a source's channels.
struct ChannelGrid: View {
    let items: [MediaItem]
    let onPlay: (MediaItem) -> Void
    let onToggleFavorite: (MediaItem) -> Void
    var onDelete: ((MediaItem) -> Void)?

    /// Two equal columns on every iPhone in portrait (375 pt fits two 150 pt cards), three when every
    /// card is a poster, more in landscape. Not scaled with Dynamic Type, so a column never drops.
    private var minimumWidth: CGFloat {
        items.allSatisfy { $0.artwork == .poster } && !items.isEmpty ? 100 : 150
    }

    var body: some View {
        // Posters among wide cards are drawn wide too: a 2:3 card beside a 16:9 one left rows uneven.
        let isWide = items.mixesArtworkShapes
        return LazyVGrid(
            // Equal columns, so every card has the same width and height.
            columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: Spacing.sm, alignment: .top)],
            spacing: Spacing.md
        ) {
            ForEach(items) { item in
                ChannelCard(
                    item: item,
                    onPlay: { onPlay(item) },
                    onToggleFavorite: { onToggleFavorite(item) },
                    onDelete: item.deleteAction(onDelete),
                    isWide: isWide
                )
            }
        }
        .padding(.horizontal, Spacing.md)
    }
}
