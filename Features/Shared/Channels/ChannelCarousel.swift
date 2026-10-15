import SwiftUI

/// A horizontally scrolling row of cards for one group.
struct ChannelCarousel: View {
    let items: [MediaItem]
    let onPlay: (MediaItem) -> Void
    let onToggleFavorite: (MediaItem) -> Void
    var onDelete: ((MediaItem) -> Void)?

    @ScaledMetric(relativeTo: .subheadline) private var cardWidth: CGFloat = 176

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: Spacing.sm) {
                ForEach(items) { item in
                    ChannelCard(
                        item: item,
                        onPlay: { onPlay(item) },
                        onToggleFavorite: { onToggleFavorite(item) },
                        onDelete: item.deleteAction(onDelete)
                    )
                    // Posters stand tall, as on a streaming shelf.
                    .frame(width: item.artwork == .poster ? min(cardWidth * 0.86, 240) : min(cardWidth, 300))
                }
            }
            .padding(.horizontal, Spacing.md)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
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

    /// Two equal columns on every iPhone in portrait (375 pt fits two 150 pt cards), three for
    /// posters, more in landscape. Not scaled with Dynamic Type, so a column never drops.
    private var minimumWidth: CGFloat {
        items.first?.artwork == .poster ? 100 : 150
    }

    var body: some View {
        LazyVGrid(
            // Equal columns, so every card has the same width and height.
            columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: Spacing.sm, alignment: .top)],
            spacing: Spacing.md
        ) {
            ForEach(items) { item in
                ChannelCard(
                    item: item,
                    onPlay: { onPlay(item) },
                    onToggleFavorite: { onToggleFavorite(item) },
                    onDelete: item.deleteAction(onDelete)
                )
            }
        }
        .padding(.horizontal, Spacing.md)
    }
}
