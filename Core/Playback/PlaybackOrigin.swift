import Foundation

/// Where the playing item was picked: the iPhone shows only what was picked there, Roadivo's CarPlay window only what
/// was picked on the car (DECISIONS 155). There's one player, so the latest pick plays.
enum PlaybackOrigin: Equatable, Sendable {
    case phone
    case car
}
