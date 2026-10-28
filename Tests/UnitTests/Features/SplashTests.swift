import Foundation
import Testing
@testable import PlayCarTV

@Suite("Opening splash")
struct SplashTests {
    private func moment(at hour: Int, _ minute: Int = 0) throws -> SplashMoment {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let date = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 10,
            day: 20,
            hour: hour,
            minute: minute
        )))
        return SplashMoment(date: date, calendar: calendar)
    }

    @Test("Sunrise in the morning, the sun high at midday, sunset in the evening, moon and stars at night")
    func followsTheClock() throws {
        #expect(try moment(at: 4, 59) == .night)
        #expect(try moment(at: 5) == .sunrise)
        #expect(try moment(at: 10, 59) == .sunrise)
        #expect(try moment(at: 11) == .midday)
        #expect(try moment(at: 16, 59) == .midday)
        #expect(try moment(at: 17) == .sunset)
        #expect(try moment(at: 19, 59) == .sunset)
        #expect(try moment(at: 20) == .night)
        #expect(try moment(at: 0) == .night)
    }

    @Test("Each time of day draws its own road and its own play-button sun, the moon at night")
    func scenes() {
        #expect(SplashMoment.allCases.map(\.time) == [.goldenHour, .day, .dusk, .night])
        #expect(Set(SplashMoment.allCases.map(\.sun.light)).count == 4, "A sun in each hour's own colour")
        #expect(Set(SplashMoment.allCases.map(\.sun.mark)).count == 4)
    }

    @Test("UI tests skip the splash unless they ask for it, unit tests always skip it; the app always shows it")
    func whenItShows() {
        let hostingTests = ["XCTestConfigurationFilePath": "/tmp/PlayCarTV.xctestconfiguration"]
        #expect(SplashView.isWanted(arguments: []))
        #expect(!SplashView.isWanted(arguments: ["-ui-testing"]))
        #expect(SplashView.isWanted(arguments: ["-ui-testing", "-show-splash"]))
        #expect(!SplashView.isWanted(arguments: [], environment: hostingTests))
    }
}
