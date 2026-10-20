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

    /// The most rows any list gets; the car may allow fewer (`CPListTemplate.maximumItemCount`), passed as `limit`.
    static let itemLimit = 100

    @MainActor
    static func build(from repository: LibraryRepository, limit: Int = itemLimit) -> CarPlayMenu {
        let limit = max(1, min(limit, itemLimit))
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
        // Library lists the groups themselves, so they're capped too: a big playlist can have hundreds.
        return CarPlayMenu(
            favorites: Array(((try? repository.favorites()) ?? []).prefix(limit)),
            recent: Array(((try? repository.recentlyPlayed(limit: 20)) ?? []).prefix(limit)),
            groups: order.prefix(limit).map { Group(title: $0, items: Array((buckets[$0] ?? []).prefix(limit))) }
        )
    }
}
