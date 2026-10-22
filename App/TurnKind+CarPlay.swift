import CarPlay

extension TurnKind {
    /// What CarPlay passes on to the car's own displays, such as an instrument cluster.
    @available(iOS 17.4, *)
    var maneuverType: CPManeuverType {
        switch self {
        case .straight: .straightAhead
        case .slightLeft: .slightLeftTurn
        case .left: .leftTurn
        case .sharpLeft: .sharpLeftTurn
        case .slightRight: .slightRightTurn
        case .right: .rightTurn
        case .sharpRight: .sharpRightTurn
        case .uTurn: .uTurn
        case .start: .startRoute
        case .arrive: .arriveAtDestination
        }
    }

    /// For CarPlay's maneuver card, white on its dark guidance colour.
    var cardSymbol: UIImage? {
        let size = UIImage.SymbolConfiguration(pointSize: 48, weight: .semibold)
        return UIImage(systemName: symbolName, withConfiguration: size)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
    }
}
