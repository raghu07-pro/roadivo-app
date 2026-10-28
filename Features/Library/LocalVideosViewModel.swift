import Foundation
import Observation
import UniformTypeIdentifiers

/// "On this iPhone": videos copied into the app from Photos or Files.
@Observable
@MainActor
final class LocalVideosViewModel {
    /// What failed, so the alert's title matches it.
    struct Problem: Equatable {
        enum Kind: Equatable {
            case load
            case importing
            case delete
        }

        let kind: Kind
        let message: String
    }

    private(set) var items: [MediaItem] = []
    private(set) var isImporting = false
    var problem: Problem?

    private let repository: LibraryRepository

    init(repository: LibraryRepository) {
        self.repository = repository
    }

    func load() {
        do {
            items = try repository.localVideos()
        } catch {
            problem = Problem(kind: .load, message: error.localizedDescription)
        }
    }

    /// Copies files (from Files, or Photos exports in a temporary folder) into the library. `skipped`
    /// counts picks that never became a file. Returns true when anything was added.
    func importFiles(_ urls: [URL], skipped: Int = 0, removingSourcesAfterwards: Bool = false) async -> Bool {
        guard !urls.isEmpty else {
            reportPartialImport(imported: 0, of: skipped)
            return false
        }
        isImporting = true
        defer {
            isImporting = false
            if removingSourcesAfterwards {
                for url in urls {
                    try? FileManager.default.removeItem(at: url) // Temporary Photos export; nothing to recover.
                }
            }
        }
        do {
            let imported = try await repository.importVideos(urls)
            load()
            reportPartialImport(imported: imported, of: urls.count + skipped)
            return true
        } catch {
            problem = Problem(kind: .importing, message: error.localizedDescription)
            return false
        }
    }

    /// The one place a partial import is reported, called once the import has finished so the
    /// alert never shows over "Importing…".
    private func reportPartialImport(imported: Int, of total: Int) {
        guard imported < total else { return }
        problem = Problem(
            kind: .importing,
            message: imported == 0
                ? String(appLocalized: "Some videos couldn't be copied from Photos.")
                : String(appLocalized: "\(imported) of \(total) videos were imported.")
        )
    }

    /// Returns true when the video was removed.
    func delete(_ item: MediaItem) -> Bool {
        do {
            try repository.deleteVideo(item.id)
            load()
            return true
        } catch {
            problem = Problem(kind: .delete, message: error.localizedDescription)
            return false
        }
    }

    /// Imports every video inside a picked folder (and its subfolders).
    func importFolder(_ folder: URL) async -> Bool {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                folder.stopAccessingSecurityScopedResource()
            }
        }
        let videos = VideoFiles.find(in: folder)
        guard !videos.isEmpty else {
            problem = Problem(
                kind: .importing,
                message: String(appLocalized: "That folder has no videos PlayCarTV can play.")
            )
            return false
        }
        return await importFiles(videos)
    }

    func beginImport() {
        isImporting = true
    }

    func endImport() {
        isImporting = false
    }
}

enum VideoFiles {
    /// Video files under `folder`, sorted by name so episodes stay in order.
    static func find(in folder: URL, fileManager: FileManager = .default) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        return enumerator.compactMap { $0 as? URL }
            .filter { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .movie) == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
