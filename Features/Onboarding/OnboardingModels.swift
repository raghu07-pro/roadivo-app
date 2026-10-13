import Foundation

struct OnboardingPage: Identifiable, Equatable {
    let id: Int
    let symbol: String
    let secondarySymbol: String
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    /// The page's light: the trip runs from golden hour to night.
    let time: RoadScene.TimeOfDay
    /// What the car's centre screen shows on this page.
    let screen: DashScreenContent

    /// Four pages, mirroring the reference app's arc: the product, the
    /// passengers, the breaks, then bringing your own content.
    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            symbol: "car.side",
            secondarySymbol: "play.fill",
            title: "Meet Roadivo",
            message: "Let the Journey Play. Your playlists and videos, in a player made for the road.",
            time: .goldenHour,
            screen: .brand
        ),
        OnboardingPage(
            id: 1,
            symbol: "figure.seated.side.right",
            secondarySymbol: "airplayvideo",
            title: "Their favorites, on the big screen",
            message: "Send video to an AirPlay car display, or mount your iPhone and switch on Car Mode.",
            time: .day,
            screen: .nowPlaying
        ),
        OnboardingPage(
            id: 2,
            symbol: "ev.charger",
            secondarySymbol: "clock.arrow.circlepath",
            title: "Charging stops become movie time",
            message: "Pick up right where you left off, and keep watching in the mini player or Picture in Picture.",
            time: .dusk,
            screen: .charging
        ),
        OnboardingPage(
            id: 3,
            symbol: "list.and.film",
            secondarySymbol: "qrcode",
            title: "Bring your own playlists",
            message: "Add an M3U link, file or QR code, or import videos from Photos and Files. Sorted automatically.",
            time: .night,
            screen: .playlists
        )
    ]
}

enum DashScreenContent: Equatable {
    case brand
    case nowPlaying
    case charging
    case playlists
}
