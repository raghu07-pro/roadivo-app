import Foundation
import Testing
@testable import Roadivo

/// Dragging across Roadivo's CarPlay window moves the video's place (DECISIONS 154).
@Suite("Car scrub")
struct CarScrubTests {
    @Test("The window's full width is the whole video")
    func fullWidthIsWholeVideo() {
        var scrub = CarScrub(start: 600, duration: 1200)
        scrub.drag(by: 250, across: 1000)
        #expect(scrub.target == 900)
        scrub.drag(by: -500, across: 1000) // Each update is the distance since the drag began.
        #expect(scrub.target == 0)
    }

    @Test("The place stays within the video")
    func staysWithinTheVideo() {
        var scrub = CarScrub(start: 100, duration: 200)
        scrub.drag(by: 5000, across: 800)
        #expect(scrub.target == 200)
        scrub.drag(by: -5000, across: 800)
        #expect(scrub.target == 0)
    }

    @Test("Before any movement, or with no width yet, the place doesn't move")
    func noMovementKeepsPlace() {
        var scrub = CarScrub(start: 42, duration: 300)
        #expect(scrub.target == 42)
        scrub.drag(by: 100, across: 0)
        #expect(scrub.target == 42)
    }

    @Test("A start beyond the end is pulled back inside the video")
    func startIsClamped() {
        #expect(CarScrub(start: 500, duration: 300).target == 300)
        #expect(CarScrub(start: -3, duration: 300).target == 0)
    }
}
