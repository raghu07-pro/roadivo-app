import Foundation
import Testing
@testable import Roadivo

@Suite("How to Connect")
struct ConnectGuideTests {
    @Test("Before Apple grants CarPlay, the guide covers the connection, AirPlay and Car Mode only")
    func withoutCarPlay() {
        let guide = ConnectGuide(hasCarPlay: false)

        #expect(guide.sections.map(\.id) == ["connect", "airplay", "carmode"])
        #expect(guide.title.key == "Connect Roadivo to Your Car")
        // No promise that Roadivo shows on the car's screen (App Review 2.3).
        let steps = guide.sections.flatMap(\.steps).map(\.key)
        #expect(!steps.contains { $0.contains("Roadivo on the car's screen") })
        #expect(guide.proNote.key == "Car Mode is included with Roadivo Pro.")
    }

    @Test("With CarPlay, the guide leads with the CarPlay steps")
    func withCarPlay() throws {
        let guide = ConnectGuide(hasCarPlay: true)

        #expect(guide.sections.map(\.id) == ["carplay", "airplay", "carmode"])
        #expect(guide.title.key == "Connect Roadivo to CarPlay")
        let carPlay = try #require(guide.sections.first)
        #expect(carPlay.steps.count == 4)
        #expect(guide.proNote.key == "CarPlay and Car Mode are included with Roadivo Pro.")
    }

    @Test("Every step is in the string catalog, so it shows translated")
    func stepsAreTranslated() throws {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Resources/Localizable.xcstrings")
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let strings = try #require(catalog?["strings"] as? [String: Any])
        for guide in [ConnectGuide(hasCarPlay: false), ConnectGuide(hasCarPlay: true)] {
            let keys = [guide.title, guide.subtitle, guide.proNote].map(\.key)
                + guide.sections.flatMap { [$0.title] + $0.steps }.map(\.key)
            for key in keys {
                #expect(strings[key] != nil, "Missing from the catalog: \(key)")
            }
        }
    }
}
