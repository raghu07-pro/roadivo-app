#if DEBUG
    import Foundation

    /// The library search's results page, as CarTV's (DECISIONS 163).
    extension CarScreenController {
        func showResults(from source: UUID?) {
            guard case let .results(search, _) = model.page else { return }
            show(.results(search, source: source))
        }

        func editSearch(speaking: Bool) {
            guard case let .results(search, _) = model.page else { return }
            model.searchInput = .choose
            show(.search(search))
            if speaking {
                startVoice()
            }
        }

        func reloadResults() {
            readLibrary()
        }

        /// The library's videos and its sources' names, for its search.
        func readLibrary() {
            guard let repository = AppEnvironment.current?.repository else { return }
            // A library that can't be read searches nothing rather than failing the page.
            model.library = (try? repository.items()) ?? []
            let sources = (try? repository.playlists()) ?? []
            model.sourceNames = Dictionary(sources.map { ($0.id, $0.name) }) { first, _ in first }
        }
    }
#endif
