import SwiftUI

struct ChannelCard: View {
    let item: MediaItem
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void
    /// Only for videos on this iPhone.
    var onDelete: (() -> Void)?

    @State private var isConfirmingDelete = false

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ArtworkTile(
                    title: item.title,
                    imageURL: item.artworkURL,
                    videoURL: item.isLocalFile ? item.streamURL : nil
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
                .overlay(alignment: .bottomLeading) {
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.45), in: Circle())
                            .padding(Spacing.xs)
                    }
                }
                Text(item.title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CardButtonStyle())
        // Lift with rounded corners into a larger preview, so the long press
        // morphs smoothly instead of popping a square snapshot of the card.
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .contextMenu {
            Button(action: onPlay) { Label("Play", systemImage: "play.fill") }
            Button(action: onToggleFavorite) {
                Label(
                    item.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: item.isFavorite ? "heart.slash" : "heart"
                )
            }
            if onDelete != nil {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    DestructiveLabel(title: "Delete", systemImage: "trash")
                }
            }
        } preview: {
            ChannelPreview(item: item)
        }
        // A centred alert: a confirmation dialog pops up beside the card on
        // iOS 26, where it reads as part of the menu rather than a question.
        .alert(Text("Delete \(item.title)?"), isPresented: $isConfirmingDelete) {
            Button("Delete Video", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The video is removed from Roadivo. The original stays in Photos or Files.")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.title))
        .accessibilityValue(item.isFavorite ? Text("Favorite") : Text(item.groupTitle))
        .accessibilityHint(Text("Plays this channel"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: item.isFavorite ? Text("Remove from Favorites") : Text("Add to Favorites")) {
            onToggleFavorite()
        }
        // The context menu isn't reachable on the merged element, so VoiceOver gets Delete as an action.
        .accessibilityActions {
            if onDelete != nil {
                Button("Delete") { isConfirmingDelete = true }
            }
        }
        .accessibilityIdentifier("channel.\(item.title)")
    }
}

/// The long-press preview: the artwork larger, with the full title and group.
private struct ChannelPreview: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ArtworkTile(
                title: item.title,
                imageURL: item.artworkURL,
                videoURL: item.isLocalFile ? item.streamURL : nil
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(item.groupTitle)
                    .font(Typography.caption)
                    .foregroundStyle(.roadMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.xxs)
        }
        .padding(Spacing.sm)
        .frame(width: 320)
        .background(.roadSurface)
    }
}
