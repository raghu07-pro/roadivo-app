import SwiftUI

struct ChannelCard: View {
    let item: MediaItem
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void
    /// Only for videos on this iPhone.
    var onDelete: (() -> Void)?
    /// Continue Watching's own actions: start over, and take the item out of the row.
    var onPlayFromBeginning: (() -> Void)?
    var onRemoveFromHistory: (() -> Void)?
    /// A poster cropped to 16:9, in a row that mixes posters with wide cards.
    var isWide = false

    @State private var isConfirmingDelete = false

    /// "42 min left" while it can be picked up again.
    private var timeLeft: String? {
        item.progress.map { String(appLocalized: "\($0.remainingText(locale: AppLanguage.shared.locale)) left") }
    }

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ArtworkTile(item: item, isWide: isWide)
                    .overlay {
                        if let progress = item.progress {
                            WatchProgressBar(fraction: progress.fraction)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        }
                    }
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
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let timeLeft {
                        Text(timeLeft)
                            .font(Typography.caption)
                            .foregroundStyle(.roadMuted)
                            .lineLimit(1)
                    } else if let year = item.year {
                        Text(String(year))
                            .font(Typography.caption)
                            .foregroundStyle(.roadMuted)
                    }
                }
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
            if item.progress != nil, let onPlayFromBeginning {
                Button(action: onPlayFromBeginning) {
                    Label("Play from Beginning", systemImage: "arrow.counterclockwise")
                }
            }
            Button(action: onToggleFavorite) {
                Label(
                    item.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: item.isFavorite ? "heart.slash" : "heart"
                )
            }
            if let onRemoveFromHistory {
                Button(action: onRemoveFromHistory) {
                    Label("Remove from Continue Watching", systemImage: "minus.circle")
                }
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
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(Text("Plays this channel"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: item.isFavorite ? Text("Remove from Favorites") : Text("Add to Favorites")) {
            onToggleFavorite()
        }
        // The context menu isn't reachable on the merged element, so VoiceOver gets its actions here.
        .accessibilityActions {
            if item.progress != nil, let onPlayFromBeginning {
                Button("Play from Beginning", action: onPlayFromBeginning)
            }
            if let onRemoveFromHistory {
                Button("Remove from Continue Watching", action: onRemoveFromHistory)
            }
            if onDelete != nil {
                Button("Delete") { isConfirmingDelete = true }
            }
        }
        .accessibilityIdentifier("channel.\(item.title)")
    }

    private var accessibilityValue: Text {
        switch (timeLeft, item.isFavorite) {
        case let (timeLeft?, true): Text("Favorite, \(timeLeft)")
        case let (timeLeft?, false): Text(timeLeft)
        case (nil, true): Text("Favorite")
        case (nil, false): Text(item.groupTitle)
        }
    }
}

/// The long-press preview: the artwork larger, with the full title and group.
private struct ChannelPreview: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ArtworkTile(item: item)
                .overlay {
                    if let progress = item.progress {
                        WatchProgressBar(fraction: progress.fraction)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                }
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
        .frame(width: item.artwork == .poster ? 240 : 320)
        .background(.roadSurface)
    }
}
