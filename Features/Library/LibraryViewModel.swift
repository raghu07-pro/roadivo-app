import Foundation
import Observation

@Observable
@MainActor
final class LibraryViewModel {
    enum Phase: Equatable {
        case loading
        case empty
        case loaded
        case failed(String)
    }

    let scope: LibraryScope
    private(set) var phase: Phase = .loading
    private(set) var items: [MediaItem] = [] {
        didSet { rebuildSections() }
    }

    private(set) var recent: [MediaItem] = []
    /// Home's sources, for its filter menu.
    private(set) var sources: [SourceOption] = []
    /// The one source Home shows, or nil for all of them.
    private(set) var sourceFilter: UUID?
    var query = "" {
        didSet {
            if query != oldValue {
                rebuildSections()
            }
        }
    }

    /// The items matching the search, stored rather than computed: filtering a large library on
    /// every read made typing stutter.
    private(set) var filtered: [MediaItem] = []
    /// `filtered`, grouped in first-seen order.
    private(set) var sections: [LibrarySection] = []

    private let repository: LibraryRepository

    init(repository: LibraryRepository, scope: LibraryScope) {
        self.repository = repository
        self.scope = scope
    }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The current items of one group, for its own screen. Read live so a favourite
    /// changed on that screen shows at once.
    func items(inGroup title: String) -> [MediaItem] {
        sections.first { $0.title == title }?.items ?? []
    }

    func load() {
        do {
            switch scope {
            case .all:
                let known = Set(sources.map(\.id))
                sources = try repository.playlists().filter { $0.kind != .localVideos }.map {
                    try SourceOption(id: $0.id, name: $0.name, count: repository.channelCount(in: $0.id))
                }
                // A deleted choice goes back to all sources, and so does a new source, so it shows.
                let isNewSource = !known.isEmpty && sources.contains { !known.contains($0.id) }
                if let chosen = sourceFilter, isNewSource || !sources.contains(where: { $0.id == chosen }) {
                    sourceFilter = nil
                }
                // Home is the channel library; imported videos live in Favorites › On this iPhone.
                items = try repository.items(in: sourceFilter).filter { !$0.isLocalFile }
                // Filtered in the fetch: filtering after the limit let 12 played videos empty the row.
                recent = try repository.continueWatching(limit: 12, in: sourceFilter)
            case .favorites:
                items = try repository.favorites()
                recent = []
            }
            phase = items.isEmpty ? .empty : .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Shows one source on Home, or all of them for nil.
    func showSource(_ id: UUID?) {
        guard id != sourceFilter else { return }
        sourceFilter = id
        load()
    }

    /// Toggles the favourite and returns the new value (nil on failure), updating the loaded items
    /// in place; the revision bump that follows reloads the other screens.
    func toggleFavorite(_ item: MediaItem) -> Bool? {
        guard let isFavorite = try? repository.toggleFavorite(item.id) else { return nil }
        if scope == .favorites, !isFavorite {
            items.removeAll { $0.id == item.id }
            phase = items.isEmpty ? .empty : .loaded
        } else if scope == .favorites {
            load()
        } else {
            setFavorite(isFavorite, for: item.id, in: &items)
            setFavorite(isFavorite, for: item.id, in: &recent)
        }
        return isFavorite
    }

    /// Removes a video on this iPhone. Returns true when it was removed.
    func deleteVideo(_ item: MediaItem) -> Bool {
        guard (try? repository.deleteVideo(item.id)) != nil else { return false }
        load()
        return true
    }

    /// After watching: Continue Watching and the cards' bars, without re-reading the whole library
    /// (a second at 30 000 channels). An unreadable store keeps what's shown.
    func reloadHistory() {
        guard phase == .loaded, let progress = try? repository.playbackProgress() else { return }
        if scope == .all, let latest = try? repository.continueWatching(limit: 12, in: sourceFilter) {
            recent = latest
        }
        guard items.contains(where: { $0.progress != progress[$0.id] }) else { return }
        items = items.map { item in
            var item = item
            item.progress = progress[item.id]
            return item
        }
    }

    /// Takes an item out of Continue Watching, with its saved place. Returns true when it was removed.
    func removeFromHistory(_ item: MediaItem) -> Bool {
        do {
            try repository.removeFromHistory(item.id)
        } catch {
            return false // Gone already (a refresh), or unsaved: the row stays as the store has it.
        }
        recent.removeAll { $0.id == item.id }
        return true
    }

    /// What next/previous step through when `item` plays: its own group.
    func queue(for item: MediaItem) -> [MediaItem] {
        let group = items.filter { $0.group == item.group }
        return group.isEmpty ? [item] : group
    }

    private func setFavorite(_ isFavorite: Bool, for id: UUID, in list: inout [MediaItem]) {
        if let index = list.firstIndex(where: { $0.id == id }) {
            list[index].isFavorite = isFavorite
        }
    }

    private func rebuildSections() {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        filtered = needle.isEmpty ? items : items.filter {
            $0.title.localizedStandardContains(needle) || $0.group.localizedStandardContains(needle)
        }
        var order: [String] = []
        var groups: [String: [MediaItem]] = [:]
        for item in filtered {
            let title = item.groupTitle
            if groups[title] == nil {
                order.append(title)
            }
            groups[title, default: []].append(item)
        }
        sections = order.map { LibrarySection(title: $0, items: groups[$0] ?? []) }
    }
}
