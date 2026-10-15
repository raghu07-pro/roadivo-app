import Foundation

extension [MediaItem] {
    /// Each group's title ("Other" for none), in the order the list first shows it.
    var groupTitles: [String] {
        var seen: Set<String> = []
        return map(\.groupTitle).filter { seen.insert($0).inserted }
    }

    func inGroup(_ title: String) -> [MediaItem] {
        filter { $0.groupTitle == title }
    }
}
