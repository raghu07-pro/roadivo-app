import Foundation
import Testing
@testable import PlayCarTV

@Suite("Voice search")
@MainActor
struct VoiceSearchModelTests {
    @Test("What's said streams into the search, then listening ends")
    func streamsTranscript() async {
        let speech = FakeSpeech(results: ["Foot", "Football"])
        let model = VoiceSearchModel(speech: speech)
        var query = ""
        model.toggle { query = $0 }
        await waitUntil { query == "Football" && model.state == .idle }
        #expect(query == "Football")
        #expect(model.state == .idle)
    }

    @Test("Without microphone or speech access, it asks the user to allow it")
    func denied() async {
        let model = VoiceSearchModel(speech: FakeSpeech(grantsAccess: false))
        model.toggle { _ in Issue.record("No text without access") }
        await waitUntil { model.state == .denied }
        #expect(model.state == .denied)
        model.dismissAlert()
        #expect(model.state == .idle)
    }

    @Test("A recognizer failure shows the unavailable alert")
    func failure() async {
        let model = VoiceSearchModel(speech: FakeSpeech(failure: SpeechError.unavailable))
        model.toggle { _ in }
        await waitUntil { model.state == .failed }
        #expect(model.state == .failed)
    }

    @Test("Tapping the mic while listening stops it")
    func tapAgainStops() async {
        let speech = FakeSpeech(results: [], holdsOpen: true)
        let model = VoiceSearchModel(speech: speech)
        model.toggle { _ in }
        await waitUntil { model.isListening }
        model.toggle { _ in }
        await waitUntil { model.state == .idle }
        #expect(speech.stopCount == 1)
        #expect(model.state == .idle)
    }

    @Test("A playing video pauses while listening, then carries on")
    func pausesPlayback() async {
        let speech = FakeSpeech(results: [], holdsOpen: true)
        let playback = FakePlayback(isPlaying: true)
        let model = VoiceSearchModel(speech: speech, playback: playback)
        model.toggle { _ in }
        await waitUntil { model.isListening && playback.pauses == 1 }
        #expect(playback.resumes == 0)
        model.toggle { _ in }
        await waitUntil { playback.resumes == 1 }
        #expect(playback.resumes == 1)
    }

    @Test("Nothing playing, nothing resumed")
    func leavesIdlePlayerAlone() async {
        let playback = FakePlayback(isPlaying: false)
        let model = VoiceSearchModel(speech: FakeSpeech(results: ["News"]), playback: playback)
        model.toggle { _ in }
        await waitUntil { playback.pauses == 1 && model.state == .idle }
        #expect(playback.resumes == 0)
        #expect(playback.releases == 1)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5)) // Polling; a cancelled sleep just polls sooner.
        }
    }
}

/// A transcriber that replays `results`, fails, or stays open until `stop()`.
@MainActor
private final class FakeSpeech: SpeechTranscribing {
    var grantsAccess = true
    var results: [String] = []
    var failure: Error?
    var holdsOpen = false
    private(set) var stopCount = 0
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?

    init(results: [String] = [], grantsAccess: Bool = true, failure: Error? = nil, holdsOpen: Bool = false) {
        self.results = results
        self.grantsAccess = grantsAccess
        self.failure = failure
        self.holdsOpen = holdsOpen
    }

    func requestAccess() async -> Bool {
        grantsAccess
    }

    func transcribe(locale: Locale) -> AsyncThrowingStream<String, Error> {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        results.forEach { continuation.yield($0) }
        if let failure {
            continuation.finish(throwing: failure)
        } else if holdsOpen {
            self.continuation = continuation
        } else {
            continuation.finish()
        }
        return stream
    }

    func stop() {
        stopCount += 1
        continuation?.finish()
        continuation = nil
    }

    func cancel() {
        stop()
    }
}

/// Records what voice search asks of the player.
@MainActor
private final class FakePlayback: PlaybackPausing {
    let isPlaying: Bool
    private(set) var pauses = 0
    private(set) var resumes = 0
    private(set) var releases = 0

    init(isPlaying: Bool) {
        self.isPlaying = isPlaying
    }

    func pauseForMicrophone() -> Bool {
        pauses += 1
        return isPlaying
    }

    func resume() {
        resumes += 1
    }

    func releaseAudio() {
        releases += 1
    }
}
