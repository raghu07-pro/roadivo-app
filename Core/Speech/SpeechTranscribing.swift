import Foundation

/// Live speech-to-text for voice search; a scripted stand-in replaces it in UI tests.
@MainActor
protocol SpeechTranscribing: AnyObject {
    /// Asks for speech recognition and microphone access; true when both are granted.
    func requestAccess() async -> Bool
    /// The transcript so far, growing as the user speaks; finishes after a pause or `stop()`.
    func transcribe(locale: Locale) -> AsyncThrowingStream<String, Error>
    /// Stops listening; what was heard so far still arrives.
    func stop()
    /// Ends at once and puts the audio back, without waiting for the last words.
    func cancel()
}

enum SpeechError: Error {
    /// No recognizer for the language, or it's offline.
    case unavailable
}
