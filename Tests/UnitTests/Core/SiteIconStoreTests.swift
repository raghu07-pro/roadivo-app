import Foundation
import os
import Testing
import UIKit
@testable import PlayCarTV

@MainActor
@Suite("Browser site icons")
struct SiteIconStoreTests {
    private let sites = Array(BrowserSite.all.prefix(3))
    private let png = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).pngData { context in
        UIColor.orange.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    }

    private func folder() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "SiteIcons-\(UUID().uuidString)")
    }

    /// Counts downloads, so a test can tell a kept icon from a fetched one.
    private final class Downloads: Sendable {
        private let count = OSAllocatedUnfairLock(initialState: 0)
        var total: Int {
            count.withLock { $0 }
        }

        func loader(returning data: Data?) -> @Sendable (URL) async throws -> Data {
            { _ in
                self.count.withLock { $0 += 1 }
                // As URLSession's: a cancelled download fails.
                try Task.checkCancellation()
                guard let data else { throw URLError(.notConnectedToInternet) }
                return data
            }
        }
    }

    @Test("Icons fetched once show at once next time, even offline")
    func keptIcons() async {
        let directory = folder()
        let first = SiteIconStore(directory: directory, load: Downloads().loader(returning: png))
        await first.refresh(sites)
        #expect(sites.allSatisfy { first.icon(for: $0) != nil })

        let offline = Downloads()
        let next = SiteIconStore(directory: directory, load: offline.loader(returning: nil))
        #expect(sites.allSatisfy { next.icon(for: $0) != nil }, "Shown before any refresh")
        await next.refresh(sites)
        #expect(offline.total == 0, "Fresh icons aren't fetched again")
    }

    @Test("A month-old icon is fetched again; a newer one isn't")
    func monthlyRefresh() async {
        let directory = folder()
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        await SiteIconStore(directory: directory, load: Downloads().loader(returning: png), now: { start })
            .refresh(sites)

        let soon = Downloads()
        await SiteIconStore(directory: directory, load: soon.loader(returning: png), now: {
            start.addingTimeInterval(10 * 24 * 60 * 60)
        }).refresh(sites)
        #expect(soon.total == 0)

        let later = Downloads()
        await SiteIconStore(directory: directory, load: later.loader(returning: png), now: {
            start.addingTimeInterval(SiteIconStore.maxAge + 60)
        }).refresh(sites)
        #expect(later.total == sites.count)
    }

    @Test("An icon that can't be fetched keeps its letter tile, and is tried again next time")
    func failedIcon() async {
        let directory = folder()
        let downloads = Downloads()
        let store = SiteIconStore(directory: directory, load: downloads.loader(returning: nil))
        await store.refresh(sites)
        #expect(sites.allSatisfy { store.icon(for: $0) == nil })
        await store.refresh(sites)
        #expect(downloads.total == sites.count * 2)
    }

    @Test("A screen that closes mid-download still gets its icons, as Discover opening the Browser")
    func closedMidDownload() async {
        let store = SiteIconStore(directory: nil, load: Downloads().loader(returning: png))
        let discover = Task { await store.refresh(sites) }
        discover.cancel()
        let browser = Task { await store.refresh(sites) }
        await discover.value
        await browser.value
        #expect(sites.allSatisfy { store.icon(for: $0) != nil })
    }

    @Test("A screen asking mid-download gets its own icons too, each fetched once")
    func askedMidDownload() async {
        let downloads = Downloads()
        let store = SiteIconStore(directory: nil, load: downloads.loader(returning: png))
        let discover = Task { await store.refresh(Array(sites.prefix(2))) }
        let car = Task { await store.refresh(sites) }
        await discover.value
        await car.value
        #expect(sites.allSatisfy { store.icon(for: $0) != nil })
        #expect(downloads.total == sites.count)
    }

    @Test("Without a folder, icons live in memory only")
    func memoryOnly() async {
        let store = SiteIconStore(directory: nil, load: Downloads().loader(returning: png))
        await store.refresh(sites)
        #expect(sites.allSatisfy { store.icon(for: $0) != nil })
        #expect(SiteIconStore(directory: nil).icon(for: sites[0]) == nil)
    }
}
