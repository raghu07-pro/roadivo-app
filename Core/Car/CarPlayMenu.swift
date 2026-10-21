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
    /// The Browser tab's sites, which open in the iPhone's Browser (DECISIONS 131).
    let sites: [BrowserSite]

    /// Where an item picks up and how long it is, for CarPlay's video rows; 0 when the length isn't known yet, as
    /// for a live channel (DECISIONS 132).
    static func videoTimes(for media: MediaItem) -> (elapsed: Double, duration: Double) {
        (media.progress?.resumePoint ?? 0, media.progress?.duration ?? 0)
    }

    /// The sites in rows of at most `perRow`, CarPlay's limit for one row of icons; the car wraps each to fit.
    func siteRows(perRow: Int) -> [[BrowserSite]] {
        let perRow = max(1, perRow)
        return stride(from: 0, to: sites.count, by: perRow).map { Array(sites[$0..<min($0 + perRow, sites.count)]) }
    }

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
            groups: order.prefix(limit).map { Group(title: $0, items: Array((buckets[$0] ?? []).prefix(limit))) },
            sites: Array(BrowserSite.all.prefix(limit))
        )
    }
}
