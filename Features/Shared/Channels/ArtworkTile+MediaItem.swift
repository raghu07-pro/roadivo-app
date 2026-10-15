import SwiftUI

extension ArtworkTile {
    /// An item's artwork in its own shape: a logo or still at 16:9, a film's poster at 2:3.
    init(item: MediaItem) {
        self.init(
            title: item.title,
            imageURL: item.artworkURL,
            videoURL: item.isLocalFile ? item.streamURL : nil,
            aspectRatio: item.artwork == .poster ? 2 / 3 : 16 / 9,
            fillsFrame: item.artwork != .logo
        )
    }
}
