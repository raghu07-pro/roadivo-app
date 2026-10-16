import Foundation
import Observation

@Observable
@MainActor
final class SourcesViewModel {
    private(set) var sources: [SourceSummary] = []
    private(set) var refreshing: Set<UUID> = []
    var errorMessage: String?

    private let repository: LibraryRepository
    private let checker: StreamChecker

    init(repository: LibraryRepository, checker: StreamChecker = .live) {
        self.repository = repository
        self.checker = checker
    }

    func load() {
        do {
            sources = try repository.playlists().map {
                let check = $0.streamCheck
                return try SourceSummary(
                    id: $0.id,
                    name: $0.name,
                    kind: $0.kind,
                    itemCount: repository.channelCount(in: $0.id),
                    host: $0.sourceHost,
                    refreshedAt: $0.refreshedAt,
                    server: $0.kind == .mediaServer ? repository.serverKind(of: $0.id) : nil,
                    refreshFailed: $0.lastRefreshError != nil,
                    streamsAnswered: check?.answered,
                    streamsChecked: check?.checked
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The screen for one source's channels.
    func detail(for source: SourceSummary) -> SourceDetailViewModel {
        SourceDetailViewModel(source: source, repository: repository, checker: checker)
    }

    /// Source Health for one source.
    func health(for source: SourceSummary) -> SourceHealthViewModel {
        SourceHealthViewModel(source: source, repository: repository, checker: checker)
    }

    /// Returns true when the library changed.
    func refresh(_ id: UUID) async -> Bool {
        refreshing.insert(id)
        defer { refreshing.remove(id) }
        do {
            try await repository.refresh(id)
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Returns true when the source was deleted. The row goes at once; a big source takes a moment.
    func delete(_ id: UUID) async -> Bool {
        sources.removeAll { $0.id == id }
        do {
            try await repository.delete(id)
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            load()
            return false
        }
    }

    func rename(_ id: UUID, to name: String) -> Bool {
        do {
            try repository.rename(id, to: name)
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
