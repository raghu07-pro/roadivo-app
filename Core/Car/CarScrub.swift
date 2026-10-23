import Foundation

/// A drag across Roadivo's CarPlay window moving the video's place: the window's full width is the whole video, as on
/// the iPhone's progress bar (DECISIONS 154). Pure, so it's unit-tested.
struct CarScrub: Equatable, Sendable {
    /// Where the video was when the drag began, in seconds.
    let start: Double
    let duration: Double
    /// Where it lands when the finger lifts.
    private(set) var target: Double

    init(start: Double, duration: Double) {
        self.start = start
        self.duration = max(duration, 0)
        target = min(max(start, 0), max(duration, 0))
    }

    /// `distance` is how far the finger has moved since the drag began, in points; right is later.
    mutating func drag(by distance: Double, across width: Double) {
        guard width > 0 else { return }
        target = min(max(start + distance / width * duration, 0), duration)
    }
}
