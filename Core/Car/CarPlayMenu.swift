import Foundation

/// What the CarPlay screen lists: the phone's library trimmed to CarPlay's list limits.
/// Pure data, so it's unit-tested without a car.
struct CarPlayMenu: Equatable {
    struct Group: Equatable {
        let title: String
        let items: [MediaItem]
    }

    let favorites: [MediaItem]
    let recent: [MediaItem]
    let groups: [Group]

    /// CarPlay lists show at most a few hundred rows; stay well inside it.
    static let itemLimit = 100

    @MainActor
    static func build(from repository: LibraryRepository) -> CarPlayMenu {
        // A read failure shows empty lists in the car rather than nothing at all.
        let items = (try? repository.items()) ?? []
        var order: [String] = []
        var buckets: [String: [MediaItem]] = [:]
        for item in items {
            if buckets[item.groupTitle] == nil {
                order.append(item.groupTitle)
            }
            buckets[item.groupTitle, default: []].append(item)
        }
        return CarPlayMenu(
            favorites: Array(((try? repository.favorites()) ?? []).prefix(itemLimit)),
            recent: Array(((try? repository.recentlyPlayed(limit: 20)) ?? []).prefix(itemLimit)),
            groups: order.map { Group(title: $0, items: Array((buckets[$0] ?? []).prefix(itemLimit))) }
        )
    }
}
