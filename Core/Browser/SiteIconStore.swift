import OSLog
import UIKit

/// The Browser's site icons, kept on the iPhone so the start page shows them at once (owner, 2026-10-20;
/// DECISIONS 129). Each comes from Google's icon service only when it's missing or a month old.
@MainActor
@Observable
final class SiteIconStore {
    private(set) var icons: [String: UIImage] = [:]

    @ObservationIgnored private let directory: URL?
    @ObservationIgnored private let load: @Sendable (URL) async throws -> Data
    @ObservationIgnored private let now: @Sendable () -> Date
    /// When each icon was fetched, kept in our own file: reading the files' dates would be a required-reason API.
    @ObservationIgnored private var fetched: [String: Date] = [:]
    @ObservationIgnored private var isRefreshing = false
    @ObservationIgnored private let logger = Logger(subsystem: "com.roadivo", category: "SiteIcons")

    nonisolated static let maxAge: TimeInterval = 30 * 24 * 60 * 60

    /// In Caches: iOS may clear it, and the icons are then fetched again.
    static func onDevice() -> SiteIconStore {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        return SiteIconStore(directory: caches?.appending(path: "SiteIcons-v2", directoryHint: .isDirectory))
    }

    /// `directory` nil keeps icons in memory only (previews and snapshot tests start with letter tiles).
    init(
        directory: URL?,
        load: @escaping @Sendable (URL) async throws -> Data = SiteIconStore.download,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.directory = directory
        self.load = load
        self.now = now
        readDisk()
    }

    func icon(for site: BrowserSite) -> UIImage? {
        icons[site.name]
    }

    /// Fetches the icons that are missing or a month old, together; the others stay as they are.
    func refresh(_ sites: [BrowserSite]) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let due = sites.filter { site in
            guard icons[site.name] != nil, let date = fetched[site.name] else { return true }
            return now().timeIntervalSince(date) > Self.maxAge
        }
        guard !due.isEmpty else { return }
        let load = load
        let results = await withTaskGroup(of: (String, Data?).self) { group in
            for site in due {
                guard let url = site.iconURL else { continue }
                // A failed icon keeps its letter tile, or its older picture, until the next try.
                group.addTask { await (site.name, try? load(url)) }
            }
            var results: [(String, Data?)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        for (name, data) in results {
            guard let data, let image = UIImage(data: data) else { continue }
            icons[name] = image
            fetched[name] = now()
            save(data, for: name)
        }
        saveDates()
    }

    nonisolated static func download(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    // MARK: Disk

    private var datesFile: URL? {
        directory?.appending(path: "fetched.json")
    }

    /// Letters and digits only ("iQIYI International" → "iQIYIInternational"), so no name needs escaping.
    private func file(for name: String) -> URL? {
        let safe = String(String.UnicodeScalarView(name.unicodeScalars.filter(CharacterSet.alphanumerics.contains)))
        return directory?.appending(path: "\(safe).png")
    }

    private func readDisk() {
        guard let datesFile, let data = try? Data(contentsOf: datesFile), // None yet: nothing kept so far.
              let dates = try? JSONDecoder().decode([String: Date].self, from: data) else { return }
        for (name, date) in dates {
            guard let file = file(for: name), let data = try? Data(contentsOf: file), // Cleared by iOS: fetched again.
                  let image = UIImage(data: data) else { continue }
            icons[name] = image
            fetched[name] = date
        }
    }

    private func save(_ data: Data, for name: String) {
        guard let directory, let file = file(for: name) else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
        } catch {
            logger.error("Icon not kept: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func saveDates() {
        guard let datesFile else { return }
        do {
            try JSONEncoder().encode(fetched).write(to: datesFile, options: .atomic)
        } catch {
            logger.error("Icon dates not kept: \(error.localizedDescription, privacy: .public)")
        }
    }
}
