/// What Cast to Screen shows, as simple as CarTV's: where the iPhone is, and one button to start or end mirroring.
/// Pure, so each case is unit-tested.
enum CastScreenState: Equatable, Sendable {
    /// Not mirroring yet: Start Mirroring.
    case ready(isCarConnected: Bool)
    /// Mirroring, but PlayCarTV isn't open on the car's screen to show it.
    case waitingForCar(isCarConnected: Bool)
    /// PlayCarTV on the car's screen shows the iPhone now.
    case connected

    static func make(isBroadcasting: Bool, isCarConnected: Bool, isCarShowing: Bool) -> CastScreenState {
        if isCarShowing {
            return .connected
        }
        return isBroadcasting ? .waitingForCar(isCarConnected: isCarConnected) : .ready(isCarConnected: isCarConnected)
    }

    /// The one button ends mirroring once it runs, and starts it otherwise.
    var isMirroring: Bool {
        if case .ready = self {
            return false
        }
        return true
    }
}
