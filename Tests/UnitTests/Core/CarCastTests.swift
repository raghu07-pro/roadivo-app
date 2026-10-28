import Foundation
import Testing
@testable import PlayCarTV

@Suite("Cast to the car")
struct CarCastTests {
    @Test("Cast to Screen says where the iPhone is, and its one button ends mirroring once it runs")
    func castScreenState() {
        let ready = CastScreenState.make(isBroadcasting: false, isCarConnected: true, isCarShowing: false)
        #expect(ready == .ready(isCarConnected: true))
        #expect(!ready.isMirroring)
        let waiting = CastScreenState.make(isBroadcasting: true, isCarConnected: false, isCarShowing: false)
        #expect(waiting == .waitingForCar(isCarConnected: false))
        #expect(waiting.isMirroring)
        let connected = CastScreenState.make(isBroadcasting: false, isCarConnected: true, isCarShowing: true)
        #expect(connected == .connected)
        #expect(connected.isMirroring)
    }

    @Test("The car's Home lists a few recent picks above the library's groups, within the car's row limit")
    func homeList() {
        let menu = CarPlayMenu(
            favorites: [],
            recent: items(10, group: "Recent"),
            groups: (0..<30).map { CarPlayMenu.Group(title: "Group \($0)", items: items(1, group: "Group \($0)")) },
            sites: []
        )
        let roomy = menu.home(limit: 24)
        #expect(roomy.recent.count == 6)
        #expect(roomy.groups.count == 18)
        #expect(roomy.groups.first?.title == "Group 0")

        let tight = menu.home(limit: 4)
        #expect(tight.recent.count == 2)
        #expect(tight.groups.count == 2)
        #expect(menu.home(limit: 1).recent.isEmpty)
        #expect(menu.home(limit: 1).groups.count == 1)
    }

    private func items(_ count: Int, group: String) -> [MediaItem] {
        (0..<count).map { index in
            MediaItem(
                id: UUID(),
                title: "\(group) \(index)",
                group: group,
                artworkURL: nil,
                streamURL: URL(fileURLWithPath: "/dev/null/\(index).mp4"),
                isLocalFile: true,
                isFavorite: false
            )
        }
    }
}
