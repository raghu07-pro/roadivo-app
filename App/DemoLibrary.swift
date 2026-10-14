#if DEBUG
    import Foundation

    /// Debug-only demo content for UI tests and screenshots; Release ships none.
    /// The streams are Apple's public HLS test streams, the names fictional.
    enum DemoLibrary {
        @MainActor
        static func seed(into environment: AppEnvironment) async {
            do {
                try await environment.repository.addFilePlaylist(name: "Road Trip", text: playlist)
                environment.router.libraryDidChange()
            } catch {
                assertionFailure("Demo seed failed: \(error)")
            }
        }

        private static let streamA =
            "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
        private static let streamB =
            "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"

        private static var playlist: String {
            // [name, group, url]
            let rows: [[String]] = [
                ["Steel Horizon · 1080p", "Movies", streamA],
                ["Midnight Courier · 4K HDR", "Movies", streamB],
                ["Ember Valley · 1080p", "Movies", streamA],
                ["Love at Dawn", "Movies", streamB],
                ["Street Interview", "Interviews", streamA],
                ["Morning Briefing", "Interviews", streamB],
                ["Founders Live", "Interviews", streamA],
                ["Football Tonight", "Sports", streamB],
                ["American Football", "Sports", streamA],
                ["Track & Field", "Sports", streamB],
                ["Coastal Echoes", "Travel", streamA],
                ["Highway Stop", "Travel", streamB],
                ["The Lighthouse Road", "Travel", streamA]
            ]
            let body = rows.map { row in
                "#EXTINF:-1 group-title=\"\(row[1])\",\(row[0])\n\(row[2])"
            }
            return (["#EXTM3U"] + body).joined(separator: "\n")
        }
    }
#endif
