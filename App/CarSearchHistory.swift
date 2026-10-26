#if DEBUG
    import Foundation

    /// The car screen's recent library searches, newest first, kept on the iPhone as CarTV keeps its own
    /// (owner, 2026-10-26; DECISIONS 163).
    @MainActor
    final class CarSearchHistory {
        private(set) var searches: [String]
        private let defaults: UserDefaults
        private static let key = "car.search.history"
        private static let limit = 10

        init(defaults: UserDefaults = .standard) {
            self.defaults = defaults
            searches = defaults.stringArray(forKey: Self.key) ?? []
        }

        func record(_ search: String) {
            let search = search.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !search.isEmpty else { return }
            searches.removeAll { $0.caseInsensitiveCompare(search) == .orderedSame }
            searches.insert(search, at: 0)
            searches = Array(searches.prefix(Self.limit))
            defaults.set(searches, forKey: Self.key)
        }

        func clear() {
            searches = []
            defaults.removeObject(forKey: Self.key)
        }
    }
#endif
