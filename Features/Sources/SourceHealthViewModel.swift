import Foundation
import Observation

/// Source Health: a source's refreshes, the entries it couldn't read, and a check of its streams
/// (its server, for a media server; its files, for On this iPhone).
@Observable
@MainActor
final class SourceHealthViewModel {
    enum Status: Equatable {
        case unchecked
        case healthy
        case attention
        case failing
    }

    let sourceID: UUID
    let name: String
    let kind: PlaylistKind
    private(set) var health: SourceHealth?
    /// The check running now, or else the last one saved.
    private(set) var report: StreamCheckReport?
    private(set) var isChecking = false
    private(set) var serverOutcome: StreamOutcome?
    private(set) var isCheckingServer = false
    private(set) var missingVideos: [MediaItem] = []
    var errorMessage: String?

    private let repository: LibraryRepository
    private let checker: StreamChecker
    private var items: [UUID: MediaItem] = [:]
    private var checkTask: Task<Void, Never>?

    init(source: SourceSummary, repository: LibraryRepository, checker: StreamChecker) {
        sourceID = source.id
        name = source.name
        kind = source.kind
        self.repository = repository
        self.checker = checker
    }

    /// Links and pasted lists check each stream; a media server checks the server instead, so
    /// the check doesn't start a transcode for every film.
    var checksStreams: Bool {
        kind == .remote || kind == .file
    }

    var status: Status {
        switch kind {
        case .localVideos:
            return missingVideos.isEmpty ? .healthy : .attention
        case .mediaServer:
            if case .failed = serverOutcome {
                return .failing
            }
            if health?.refreshFailed == true {
                return .attention
            }
            return serverOutcome == nil ? .unchecked : .healthy
        case .remote, .file:
            let playlistTrouble = health?.refreshFailed == true || (health?.issues?.total ?? 0) > 0
            guard let report, report.checked > 0 else { return playlistTrouble ? .attention : .unchecked }
            if report.failed * 2 > report.checked {
                return .failing
            }
            return report.failed > 0 || report.slow > 0 || playlistTrouble ? .attention : .healthy
        }
    }

    func load() {
        do {
            health = try repository.health(of: sourceID)
            if !isChecking {
                report = health?.streamCheck
            }
            if kind == .localVideos {
                missingVideos = try repository.missingVideos()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Checks every stream, two at a time, updating the counts as each answers.
    func checkStreams() {
        guard checksStreams, !isChecking else { return }
        let all: [MediaItem]
        do {
            all = try repository.items(in: sourceID)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        items = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        report = StreamCheckReport(checkedAt: .now, total: all.count)
        errorMessage = nil
        isChecking = true
        let targets = all.map { StreamTarget(id: $0.id, url: $0.streamURL) }
        checkTask = Task {
            // The task already holds the model until the check ends (`stop()` on leaving cancels it).
            await checker.check(targets) { @MainActor target, outcome in
                self.record(target, outcome)
            }
            finish()
        }
    }

    func stop() {
        checkTask?.cancel()
    }

    func checkServer() async {
        guard kind == .mediaServer, !isCheckingServer else { return }
        guard let url = repository.serverCheckURL(for: sourceID) else {
            errorMessage = SourceSecretError.missing.localizedDescription
            return
        }
        isCheckingServer = true
        serverOutcome = await checker.probe.probe(url)
        isCheckingServer = false
    }

    /// The channel behind a problem, to play it.
    func item(for problem: StreamCheckReport.Problem) -> MediaItem? {
        if items.isEmpty, let all = try? repository.items(in: sourceID) {
            items = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
        return items[problem.id]
    }

    private func record(_ target: StreamTarget, _ outcome: StreamOutcome) {
        // Offline says nothing about the streams: stop, and keep the last check.
        guard errorMessage == nil else { return }
        if outcome == .failed(.offline) {
            errorMessage = StreamProblem.offline.description
            checkTask?.cancel()
            return
        }
        guard let item = items[target.id] else { return }
        report?.record(item, outcome)
    }

    private func finish() {
        isChecking = false
        checkTask = nil
        if errorMessage == nil, var report, report.checked + report.unchecked > 0 {
            report.checkedAt = .now
            report.isComplete = report.checked + report.unchecked >= report.total
            do {
                try repository.saveStreamCheck(report, for: sourceID)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        load()
    }
}
