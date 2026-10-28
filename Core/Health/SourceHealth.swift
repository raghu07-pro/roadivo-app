import Foundation

/// What PlayCarTV knows about a source's health: its refreshes, the entries it couldn't read and the
/// last stream check. Shown by Source Health.
struct SourceHealth: Equatable {
    let kind: PlaylistKind
    let channelCount: Int
    /// The last time the channels were downloaded (or added) successfully.
    let refreshedAt: Date?
    let lastRefreshAttemptAt: Date?
    /// Why the last refresh failed; nil when it worked or none was tried.
    let lastRefreshError: String?
    /// nil when never measured (a source added before Source Health, or a media server).
    let issues: M3UParser.Issues?
    let streamCheck: StreamCheckReport?

    var refreshFailed: Bool {
        lastRefreshError != nil
    }
}

extension Playlist {
    func record(_ issues: M3UParser.Issues) {
        skippedWithoutLink = issues.withoutLink
        skippedUnsupportedLink = issues.unsupportedLink
    }

    var issues: M3UParser.Issues? {
        guard let skippedWithoutLink, let skippedUnsupportedLink else { return nil }
        return M3UParser.Issues(withoutLink: skippedWithoutLink, unsupportedLink: skippedUnsupportedLink)
    }

    /// The saved stream check; an unreadable one is as good as none.
    var streamCheck: StreamCheckReport? {
        streamCheckData.flatMap { try? JSONDecoder().decode(StreamCheckReport.self, from: $0) }
    }
}
