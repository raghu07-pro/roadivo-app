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
    private(set) var items: [MediaItem] = []
    private(set) var recent: [MediaItem] = []
    var query = ""

    private let repository: LibraryRepository

    init(repository: LibraryRepository, scope: LibraryScope) {
        self.repository = repository
        self.scope = scope
    }

    /// The items matching the search, grouped in first-seen order.
    var sections: [LibrarySection] {
        var order: [String] = []
        var groups: [String: [MediaItem]] = [:]
        for item in filtered {
            let title = item.groupTitle
            if groups[title] == nil {
                order.append(title)
            }
            groups[title, default: []].append(item)
        }
        return order.map { LibrarySection(title: $0, items: groups[$0] ?? []) }
    }

    var filtered: [MediaItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }
        return items.filter {
            $0.title.localizedStandardContains(needle) || $0.group.localizedStandardContains(needle)
        }
    }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func load() {
        do {
            switch scope {
            case .all:
                items = try repository.items()
                recent = try repository.recentlyPlayed()
            case .favorites:
                items = try repository.favorites()
                recent = []
            }
            phase = items.isEmpty ? .empty : .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Toggles the favourite and returns the new value, or nil if it failed.
    func toggleFavorite(_ item: MediaItem) -> Bool? {
        guard let isFavorite = try? repository.toggleFavorite(item.id) else { return nil }
        load()
        return isFavorite
    }

    /// Removes a video on this iPhone. Returns true when it was removed.
    func deleteVideo(_ item: MediaItem) -> Bool {
        guard (try? repository.deleteVideo(item.id)) != nil else { return false }
        load()
        return true
    }

    /// What next/previous step through when `item` plays: its own group.
    func queue(for item: MediaItem) -> [MediaItem] {
        let group = items.filter { $0.group == item.group }
        return group.isEmpty ? [item] : group
    }
}
