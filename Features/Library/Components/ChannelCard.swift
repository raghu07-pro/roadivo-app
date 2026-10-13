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
        .buttonStyle(PressableStyle())
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
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            Text("Delete \(item.title)?"),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Video", role: .destructive) { onDelete?() }
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
        .accessibilityIdentifier("channel.\(item.title)")
    }
}
