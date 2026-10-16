import Foundation
import Observation

/// One source's channels, from Manage Sources: its groups as chips, plus Refresh, Rename,
/// Copy Link and Delete.
@Observable
@MainActor
final class SourceDetailViewModel {
    let sourceID: UUID
    let kind: PlaylistKind
    private(set) var name: String
    private(set) var items: [MediaItem] = [] {
        didSet { rebuildGroups() }
    }

    /// The source's groups, as chips.
    private(set) var groups: [String] = []
    /// The chip shown: the first group to begin with.
    var group = "" {
        didSet {
            if group != oldValue {
                rebuildVisible()
            }
        }
    }

    /// The items the chosen chip shows, stored so a big source isn't filtered on every redraw.
    private(set) var visible: [MediaItem] = []
    private(set) var isLoaded = false
    private(set) var isRefreshing = false
    var errorMessage: String?

    private let repository: LibraryRepository
    private let checker: StreamChecker

    init(source: SourceSummary, repository: LibraryRepository, checker: StreamChecker = .live) {
        sourceID = source.id
        kind = source.kind
        name = source.name
        self.repository = repository
        self.checker = checker
    }

    /// Source Health for this source.
    func health() -> SourceHealthViewModel {
        let summary = SourceSummary(
            id: sourceID, name: name, kind: kind, itemCount: items.count, host: nil, refreshedAt: nil
        )
        return SourceHealthViewModel(source: summary, repository: repository, checker: checker)
    }

    var canRefresh: Bool {
        kind == .remote || kind == .mediaServer
    }

    var canCopyLink: Bool {
        kind == .remote
    }

    /// Chips only help when there's more than one group.
    var showsGroups: Bool {
        groups.count > 1
    }

    func load() {
        do {
            items = try repository.items(in: sourceID)
            isLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Downloads the source again. Returns true when the library changed.
    func refresh() async -> Bool {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await repository.refresh(sourceID)
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func rename(to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != name else { return false }
        do {
            try repository.rename(sourceID, to: trimmed)
            name = trimmed
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Returns true when the source was deleted.
    func delete() async -> Bool {
        do {
            try await repository.delete(sourceID)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// The link the source was added from (often with the provider's login in it).
    func link() -> String? {
        do {
            guard let link = try repository.sourceLink(sourceID) else {
                errorMessage =
                    String(appLocalized: "This source's link isn't on this iPhone. Add the source again to copy it.")
                return nil
            }
            return link.absoluteString
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Returns the new favourite state, or nil when it couldn't change.
    func toggleFavorite(_ item: MediaItem) -> Bool? {
        guard let isFavorite = try? repository.toggleFavorite(item.id) else { return nil }
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isFavorite = isFavorite
        }
        return isFavorite
    }

    private func rebuildGroups() {
        groups = items.groupTitles
        // A refresh can drop the group on screen; the first one takes its place.
        if !groups.contains(group) {
            group = groups.first ?? ""
        }
        rebuildVisible()
    }

    private func rebuildVisible() {
        visible = items.inGroup(group)
    }
}
