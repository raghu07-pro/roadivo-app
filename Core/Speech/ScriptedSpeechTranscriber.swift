import Foundation

/// Voice search without a microphone, for UI tests and previews: "hears" `phrase` a word at a time.
@MainActor
final class ScriptedSpeechTranscriber: SpeechTranscribing {
    let phrase: String
    private var current: Task<Void, Never>?

    init(phrase: String) {
        self.phrase = phrase
    }

    func requestAccess() async -> Bool {
        true
    }

    func transcribe(locale: Locale) -> AsyncThrowingStream<String, Error> {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let words = phrase.split(separator: " ").map(String.init)
        let task = Task {
            for count in words.indices {
                try? await Task.sleep(for: .milliseconds(300)) // Cancellation is checked just below.
                guard !Task.isCancelled else { break }
                continuation.yield(words[...count].joined(separator: " "))
            }
            continuation.finish()
        }
        current = task
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func stop() {
        current?.cancel()
    }

    func cancel() {
        current?.cancel()
    }
}
