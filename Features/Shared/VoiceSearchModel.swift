import Foundation
import Observation

/// Search by voice: asks for access on first use, then streams what's said into the search text.
@Observable
@MainActor
final class VoiceSearchModel {
    enum State: Equatable {
        case idle
        case listening
        /// Microphone or speech recognition is off for Roadivo.
        case denied
        case failed
    }

    private(set) var state: State = .idle
    private let speech: SpeechTranscribing
    private weak var playback: PlaybackPausing?
    private var task: Task<Void, Never>?

    init(speech: SpeechTranscribing, playback: PlaybackPausing? = nil) {
        self.speech = speech
        self.playback = playback
    }

    var isListening: Bool {
        state == .listening
    }

    /// Starts listening, or stops if already listening. `onText` gets the transcript as it grows.
    func toggle(onText: @escaping @MainActor (String) -> Void) {
        if isListening {
            speech.stop()
            return
        }
        task?.cancel()
        task = Task {
            guard await speech.requestAccess() else {
                state = .denied
                return
            }
            guard !Task.isCancelled else { return }
            state = .listening
            // The microphone can't share the car's audio with the video, so it pauses until done.
            let resumes = playback?.pauseForMicrophone() ?? false
            do {
                for try await text in speech.transcribe(locale: AppLocale.current) {
                    onText(text)
                }
                state = .idle
            } catch {
                state = .failed
            }
            if resumes {
                playback?.resume()
            } else {
                playback?.releaseAudio()
            }
        }
    }

    /// Closes the "allow" or "unavailable" alert.
    func dismissAlert() {
        if state == .denied || state == .failed {
            state = .idle
        }
    }

    /// Stops listening when the screen goes away. The transcriber hands the audio back first, so
    /// a paused video then resumes cleanly.
    func cancel() {
        speech.cancel()
        task?.cancel()
        state = .idle
    }
}
