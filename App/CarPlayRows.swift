import CarPlay

/// A playable CarPlay row's look, shared by both CarPlay apps: title, group, a symbol until its picture arrives,
/// how much is watched, and whether it's playing. Callers add what a tap does.
@MainActor
enum CarPlayRows {
    static func item(for media: MediaItem, artwork: CarPlayArtwork) -> CPListItem {
        let item = CPListItem(
            text: media.title,
            detailText: media.groupTitle,
            image: UIImage(systemName: media.isLocalFile ? "film" : "play.tv")
        )
        if let picture = artwork.picture(for: media, ready: { [weak item] in item?.setImage($0) }) {
            item.setImage(picture)
        }
        if let progress = media.progress {
            item.playbackProgress = progress.fraction
        }
        item.isPlaying = media.id == AppEnvironment.current?.playback.current?.id
        return item
    }
}
