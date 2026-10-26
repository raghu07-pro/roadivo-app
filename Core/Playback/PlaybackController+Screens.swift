import Foundation

extension PlaybackController {
    /// Play on iPhone and Play on Car Display: the video changes screens, playing on from its place (DECISIONS 165).
    func move(to origin: PlaybackOrigin) {
        guard current != nil else { return }
        self.origin = origin
    }
}
