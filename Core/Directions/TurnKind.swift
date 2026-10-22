import Foundation

/// Which way a maneuver goes, read from the road's shape rather than Maps' wording, so it works in every language.
enum TurnKind: Equatable, Sendable {
    case straight
    case slightLeft
    case left
    case sharpLeft
    case slightRight
    case right
    case sharpRight
    case uTurn
    /// The route's first maneuver, with no road behind the car to measure a turn from.
    case start
    case arrive

    /// From the heading arriving at the maneuver to the heading leaving it, in degrees clockwise from north.
    init(from bearingIn: Double, to bearingOut: Double) {
        var change = (bearingOut - bearingIn).truncatingRemainder(dividingBy: 360)
        if change > 180 {
            change -= 360
        } else if change < -180 {
            change += 360
        }
        switch change {
        case ..<(-170): self = .uTurn
        case ..<(-120): self = .sharpLeft
        case ..<(-45): self = .left
        case ..<(-15): self = .slightLeft
        case ...15: self = .straight
        case ...45: self = .slightRight
        case ...120: self = .right
        case ...170: self = .sharpRight
        default: self = .uTurn
        }
    }

    /// The SF Symbol on CarPlay's maneuver card.
    var symbolName: String {
        switch self {
        case .straight: "arrow.up"
        case .slightLeft: "arrow.up.left"
        case .left: "arrow.turn.up.left"
        case .sharpLeft: "arrow.down.left"
        case .slightRight: "arrow.up.right"
        case .right: "arrow.turn.up.right"
        case .sharpRight: "arrow.down.right"
        case .uTurn: "arrow.uturn.down"
        case .start: "arrow.triangle.turn.up.right.diamond.fill"
        case .arrive: "flag.checkered"
        }
    }
}
