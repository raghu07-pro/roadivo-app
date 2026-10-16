import AVFoundation

/// A screen or car a profile can be saved for, as iOS reports it on the audio route (DECISIONS 111).
struct Receiver: Hashable, Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case airPlay
        case carPlay
        /// An HDMI adapter, or a USB-C (DisplayPort) display.
        case wired
    }

    let kind: Kind
    /// iOS's id for the route, which Apple doesn't promise stays the same.
    let uid: String
    /// What iOS calls it: an AirPlay receiver's own name, but only "CarPlay" for any car.
    let name: String

    /// The same receiver: by id, or by name since the id can change between connections.
    func matches(_ other: Receiver) -> Bool {
        kind == other.kind && (uid == other.uid || name == other.name)
    }

    /// The receiver among the route's outputs: AirPlay first (where video goes), then CarPlay, then a
    /// wired display. Bluetooth isn't one: iOS reports a car kit like headphones.
    static func current(in outputs: [RouteOutput]) -> Receiver? {
        let order: [(AVAudioSession.Port, Kind)] = [
            (.airPlay, .airPlay), (.carAudio, .carPlay), (.HDMI, .wired), (.displayPort, .wired)
        ]
        for (port, kind) in order {
            if let output = outputs.first(where: { $0.port == port }) {
                return Receiver(kind: kind, uid: output.uid, name: output.name)
            }
        }
        return nil
    }
}

/// One output of the audio route, separated from `AVAudioSession` so tests can feed routes in.
struct RouteOutput: Sendable {
    let port: AVAudioSession.Port
    let name: String
    let uid: String

    init(_ port: AVAudioSession.Port, _ name: String, uid: String? = nil) {
        self.port = port
        self.name = name
        self.uid = uid ?? name
    }
}
