import Foundation

/// Which screen shows the video: the iPhone, or Roadivo's CarPlay window (DECISIONS 155, 165). Where it's picked
/// decides; Play on Phone and Play on Car Display move it. There's one player, so the latest pick plays.
enum PlaybackOrigin: Equatable, Sendable {
    case phone
    case car
}
