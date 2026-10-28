import Foundation

/// Why the paywall is showing, so the header can say what the user just hit.
enum PaywallReason: String, Identifiable {
    case intro
    case settings
    case sources
    case carMode

    var id: String {
        rawValue
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .intro, .settings: "TV for the Road. Everything unlocked."
        case .sources: "The free plan includes one source. Go Pro for as many as you like."
        case .carMode: "Car Mode is part of PlayCarTV Pro."
        }
    }
}

struct PaywallFeature: Identifiable {
    let id: Int
    let symbol: String
    let title: LocalizedStringResource
    let detail: LocalizedStringResource

    static let all: [PaywallFeature] = [
        PaywallFeature(
            id: 0,
            symbol: "infinity",
            title: "Unlimited sources",
            detail: "Every playlist and media server you have"
        ),
        PaywallFeature(
            id: 1,
            symbol: "car.fill",
            title: "Car Mode",
            detail: CarPlayAvailability.isEnabled
                ? "On CarPlay, and on a mounted iPhone"
                : "Landscape controls on a mounted iPhone"
        ),
        PaywallFeature(
            id: 2,
            symbol: "server.rack",
            title: "Media servers",
            detail: "Plex, Jellyfin, Emby and Xtream together"
        ),
        PaywallFeature(
            id: 3,
            symbol: "hand.raised.fill",
            title: "No ads, ever",
            detail: "Free or Pro, no ads or tracking"
        )
    ]
}
