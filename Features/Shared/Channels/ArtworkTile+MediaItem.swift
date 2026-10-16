import SwiftUI

extension ArtworkTile {
    /// An item's artwork in its own shape: a logo or still at 16:9, a film's poster at 2:3. `isWide`
    /// crops a poster to 16:9, for a row that mixes shapes.
    init(item: MediaItem, isWide: Bool = false) {
        self.init(
            title: item.title,
            imageURL: item.artworkURL,
            videoURL: item.isLocalFile ? item.streamURL : nil,
            aspectRatio: item.artwork == .poster && !isWide ? 2 / 3 : 16 / 9,
            fillsFrame: item.artwork != .logo
        )
    }
}
