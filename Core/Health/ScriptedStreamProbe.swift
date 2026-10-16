import Foundation

/// Stream checks without the network, for UI tests and screenshots: links with "_variant" in them
/// are "not found", every other one answers.
struct ScriptedStreamProbe: StreamProbing {
    func probe(_ url: URL) async -> StreamOutcome {
        try? await Task.sleep(for: .milliseconds(120)) // Only paces the progress; cancelling ends it.
        return url.absoluteString.contains("_variant") ? .failed(.notFound) : .working(milliseconds: 180)
    }
}

extension StreamChecker {
    static let live = StreamChecker(probe: StreamProbe())
}
