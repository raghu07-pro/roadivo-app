import AVFoundation
import OSLog
import Speech

/// Speech-to-text on the iPhone where the language supports it, otherwise Apple's speech service.
/// Stops on its own after a short pause, and puts the audio session back as it was.
@MainActor
final class SpeechTranscriber: SpeechTranscribing {
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silence: Task<Void, Never>?
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?
    private var restoreSession: (() -> Void)?
    private var isStopping = false
    private var hasTap = false
    private let logger = Logger(subsystem: "com.roadivo", category: "Speech")

    func requestAccess() async -> Bool {
        guard await SystemCallbacks.speechAuthorized() else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func transcribe(locale: Locale) -> AsyncThrowingStream<String, Error> {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        finish()
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.finish() }
        }
        do {
            try start(locale: locale)
        } catch {
            logger.error("Voice search: \(error.localizedDescription, privacy: .public)")
            end(throwing: error)
        }
        return stream
    }

    func cancel() {
        end(throwing: nil)
    }

    /// Stops listening; the recognizer still delivers what it heard.
    func stop() {
        guard request != nil, !isStopping else { return }
        isStopping = true
        stopAudio()
        request?.endAudio()
        armTimer(seconds: 2) // In case the final result never comes.
    }

    // MARK: Listening

    private func start(locale: Locale) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(),
              recognizer.isAvailable else { throw SpeechError.unavailable }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .search
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request
        isStopping = false

        let session = AVAudioSession.sharedInstance()
        let previous = (session.category, session.mode, session.routeSharingPolicy, session.categoryOptions)
        // Set first, so a failure below still restores. Voice search then resumes or releases the audio.
        restoreSession = {
            // Best effort: if it fails, the next playback sets the session up again.
            try? session.setCategory(previous.0, mode: previous.1, policy: previous.2, options: previous.3)
        }
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true)

        SystemCallbacks.feed(engine.inputNode, into: request)
        hasTap = true
        engine.prepare()
        try engine.start()

        task = SystemCallbacks.recognize(request, with: recognizer) { [weak self] text, isFinal, error in
            Task { @MainActor in self?.received(text: text, isFinal: isFinal, error: error) }
        }
        armTimer(seconds: 6) // Nothing said at all.
    }

    private func received(text: String?, isFinal: Bool, error: Error?) {
        if let text, !text.isEmpty {
            continuation?.yield(text)
            if !isStopping {
                armTimer(seconds: 1.5) // A pause ends the search phrase.
            }
        }
        if isFinal {
            end(throwing: nil)
        } else if let error {
            // After stop() the task reports a cancellation; silence reports "no speech". Neither is a failure.
            end(throwing: isStopping || Self.isNoSpeech(error) ? nil : error)
        }
    }

    private func armTimer(seconds: Double) {
        silence?.cancel()
        silence = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds)) // Cancelled when a newer timer replaces it.
            guard !Task.isCancelled, let self else { return }
            if isStopping {
                end(throwing: nil)
            } else {
                stop()
            }
        }
    }

    // MARK: Teardown

    private func end(throwing error: Error?) {
        let continuation = continuation
        self.continuation = nil
        finish()
        if let error {
            continuation?.finish(throwing: error)
        } else {
            continuation?.finish()
        }
    }

    private func finish() {
        silence?.cancel()
        silence = nil
        stopAudio()
        task?.cancel()
        task = nil
        request = nil
        isStopping = false
        restoreSession?()
        restoreSession = nil
    }

    /// The tap goes even if the engine never started, or the next search would add a second one and crash.
    private func stopAudio() {
        if engine.isRunning {
            engine.stop()
        }
        if hasTap {
            engine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
    }

    private static func isNoSpeech(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == "kAFAssistantErrorDomain" && error.code == 1110
    }
}

/// iOS calls these back on its own queues. Made outside the main actor, so Swift 6 doesn't assume
/// they run on the main thread (and stop the app when they don't).
private enum SystemCallbacks {
    static func speechAuthorized() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }

    static func feed(_ input: AVAudioInputNode, into request: SFSpeechAudioBufferRecognitionRequest) {
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
    }

    static func recognize(
        _ request: SFSpeechAudioBufferRecognitionRequest,
        with recognizer: SFSpeechRecognizer,
        onResult: @escaping @Sendable (String?, Bool, Error?) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            onResult(result?.bestTranscription.formattedString, result?.isFinal ?? false, error)
        }
    }
}
