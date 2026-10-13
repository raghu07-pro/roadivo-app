import Foundation
import Observation
import UniformTypeIdentifiers

/// "On this iPhone": videos copied into the app from Photos or Files.
@Observable
@MainActor
final class LocalVideosViewModel {
    private(set) var items: [MediaItem] = []
    private(set) var isImporting = false
    var errorMessage: String?

    private let repository: LibraryRepository

    init(repository: LibraryRepository) {
        self.repository = repository
    }

    func load() {
        do {
            items = try repository.localVideos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Copies files (from Files, or Photos exports in a temporary folder) into
    /// the library. Returns true when anything was added.
    func importFiles(_ urls: [URL], removingSourcesAfterwards: Bool = false) -> Bool {
        guard !urls.isEmpty else { return false }
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
            try repository.importVideos(urls)
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Returns true when the video was removed.
    func delete(_ item: MediaItem) -> Bool {
        do {
            try repository.deleteVideo(item.id)
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Imports every video inside a picked folder (and its subfolders).
    func importFolder(_ folder: URL) -> Bool {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                folder.stopAccessingSecurityScopedResource()
            }
        }
        let videos = VideoFiles.find(in: folder)
        guard !videos.isEmpty else {
            errorMessage = String(appLocalized: "That folder has no videos Roadivo can play.")
            return false
        }
        return importFiles(videos)
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
