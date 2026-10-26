#if DEBUG
    import Foundation

    /// Pages saved with the car browser's star, kept on the iPhone so they stay in the Browser tab and on the Start
    /// Page after the browser closes, as CarTV's bookmarks do (owner, 2026-10-26; DECISIONS 163).
    @MainActor
    final class CarBookmarks {
        private(set) var pages: [CarScreenModel.SavedPage]
        private let defaults: UserDefaults
        private static let key = "car.browser.bookmarks"

        init(defaults: UserDefaults = .standard) {
            self.defaults = defaults
            // Unreadable data starts an empty list rather than failing the car's screen.
            pages = defaults.data(forKey: Self.key)
                .flatMap { try? JSONDecoder().decode([CarScreenModel.SavedPage].self, from: $0) } ?? []
        }

        func contains(_ url: URL?) -> Bool {
            pages.contains { $0.url == url }
        }

        /// Saves the page, or removes it when it's saved already.
        func toggle(title: String, url: URL) {
            if let index = pages.firstIndex(where: { $0.url == url }) {
                pages.remove(at: index)
            } else {
                let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                pages.append(.init(title: name.isEmpty ? WebAddress.displayName(of: url) : name, url: url))
            }
            if let data = try? JSONEncoder().encode(pages) { // A list of titles and addresses always encodes.
                defaults.set(data, forKey: Self.key)
            }
        }
    }
#endif
