import Foundation
import Testing
@testable import Roadivo

@Suite("Playback progress")
struct PlaybackProgressTests {
    @Test("A film stopped part-way picks up where it stopped")
    func resumesMidway() {
        let progress = PlaybackProgress(position: 1500, duration: 3600)
        #expect(progress.resumePoint == 1500)
        #expect(!progress.isFinished)
        #expect(abs(progress.fraction - 1500.0 / 3600) < 0.0001)
        #expect(progress.remaining == 2100)
    }

    @Test("Under a minute in, the next play starts from the beginning")
    func tooEarlyToResume() {
        #expect(PlaybackProgress(position: 59, duration: 3600).resumePoint == nil)
        #expect(PlaybackProgress(position: 60, duration: 3600).resumePoint == 60)
    }

    @Test("Videos under five minutes always start from the beginning")
    func shortVideosStartOver() {
        #expect(PlaybackProgress(position: 200, duration: 299).resumePoint == nil)
        #expect(PlaybackProgress(position: 200, duration: 300).resumePoint == 200)
    }

    @Test("From 90 % it counts as watched, with nothing to pick up")
    func finishedAtNinetyPercent() {
        let finished = PlaybackProgress(position: 3240, duration: 3600)
        #expect(finished.isFinished)
        #expect(finished.resumePoint == nil)
        #expect(!PlaybackProgress(position: 3239, duration: 3600).isFinished)
    }

    @Test("The share watched stays between 0 and 1, even past the end or with no length")
    func fractionStaysInRange() {
        #expect(PlaybackProgress(position: 4000, duration: 3600).fraction == 1)
        #expect(PlaybackProgress(position: -5, duration: 3600).fraction == 0)
        #expect(PlaybackProgress(position: 10, duration: 0).fraction == 0)
    }

    @Test("Time left rounds up to the minute, in hours and minutes")
    func timeLeft() {
        let english = Locale(identifier: "en_US")
        #expect(PlaybackProgress(position: 1500, duration: 3600).remainingText(locale: english) == "35 min")
        #expect(PlaybackProgress(position: 0, duration: 6120).remainingText(locale: english) == "1 hr, 42 min")
        #expect(PlaybackProgress(position: 3590, duration: 3600).remainingText(locale: english) == "1 min")
    }
}
