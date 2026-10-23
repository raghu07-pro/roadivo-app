import Foundation

/// What Roadivo's own CarPlay window shows (DECISIONS 152). Pure, so every case is unit-tested.
enum CarWindowState: Equatable, Sendable {
    /// Not Pro: watching in the car is part of Pro.
    case upgrade
    /// Nothing playing: Roadivo's screen under the four tab buttons.
    case home
    /// Playing and parked: the video, full screen.
    case video
    /// Playing while moving: the sound plays on, the picture doesn't.
    case driving
    /// Playing with Location off: parked can't be known, so no picture.
    case needsLocation

    static func make(isPro: Bool, isPlaying: Bool, isParked: Bool, isLocationDenied: Bool) -> CarWindowState {
        guard isPro else { return .upgrade }
        guard isPlaying else { return .home }
        if isLocationDenied {
            return .needsLocation
        }
        return isParked ? .video : .driving
    }

    /// The tabs hide while something plays; Close brings them back.
    var showsTabs: Bool {
        self == .home
    }
}
