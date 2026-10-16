import Foundation

extension Receiver.Kind {
    var title: LocalizedStringResource {
        switch self {
        case .airPlay: "AirPlay"
        case .carPlay: "CarPlay"
        case .wired: "Wired Display"
        }
    }

    var symbol: String {
        switch self {
        case .airPlay: "airplayvideo"
        case .carPlay: "car.fill"
        case .wired: "cable.connector"
        }
    }
}

extension VideoAspect {
    var title: LocalizedStringResource {
        switch self {
        case .fit: "Fit"
        case .fill: "Fill"
        case .stretch: "Stretch"
        }
    }
}

extension DisplayProfile {
    /// Its own name, or what iOS calls the receiver if the name was cleared.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? (receiver?.name ?? "") : trimmed
    }
}
