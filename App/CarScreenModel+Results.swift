#if DEBUG
    import Foundation

    extension CarScreenModel {
        /// One source's matches on the results page, as CarTV's "Local  1 items ›".
        struct ResultSection: Identifiable, Equatable {
            let id: UUID
            let title: String
            let items: [MediaItem]
        }

        /// What's searched for, by source in the library's order, as `libraryResults` matches it.
        var resultSections: [ResultSection] {
            let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !needle.isEmpty else { return [] }
            var order: [UUID] = []
            var matches: [UUID: [MediaItem]] = [:]
            for item in library {
                guard let source = item.sourceID,
                      item.title.localizedStandardContains(needle) || item.groupTitle.localizedStandardContains(needle)
                else { continue }
                if matches[source] == nil {
                    order.append(source)
                }
                matches[source, default: []].append(item)
            }
            return order.map { id in
                ResultSection(id: id, title: sourceNames[id] ?? "", items: matches[id] ?? [])
            }
        }
    }
#endif
