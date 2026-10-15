import Foundation

// The steps are prose; wrapping them mid-sentence hurts more than it helps.
// swiftlint:disable line_length

/// "How to Connect": the steps for each way to the car. The CarPlay steps appear only once Apple has
/// granted the entitlement (`CarPlayAvailability`); until then the guide makes no CarPlay promise.
struct ConnectGuide {
    struct Section: Identifiable {
        let id: String
        let title: LocalizedStringResource
        let systemImage: String
        let steps: [LocalizedStringResource]
    }

    let hasCarPlay: Bool

    var title: LocalizedStringResource {
        hasCarPlay ? "Connect Roadivo to CarPlay" : "Connect Roadivo to Your Car"
    }

    var subtitle: LocalizedStringResource {
        hasCarPlay
            ? "Watch on the car's screen while parked, listen while you drive, or use a mounted iPhone."
            : "Hear Roadivo through the car, watch on its screen with AirPlay, or use a mounted iPhone."
    }

    /// What Pro adds here, for someone without it.
    var proNote: LocalizedStringResource {
        hasCarPlay ? "CarPlay and Car Mode are included with Roadivo Pro." : "Car Mode is included with Roadivo Pro."
    }

    var sections: [Section] {
        [hasCarPlay ? carPlay : connect, airPlay, carMode]
    }

    private var carPlay: Section {
        Section(id: "carplay", title: "CarPlay", systemImage: "car.front.waves.up", steps: [
            Self.plugIn,
            "Find Roadivo on the car's screen. Not there? On your iPhone, open Settings › General › CarPlay, choose your car, tap Customize and add Roadivo.",
            "Open Roadivo on the car's screen and pick from Favorites, Recent or Library.",
            "Video plays on the car's screen while parked, in cars that support CarPlay video. While driving, you hear the sound only."
        ])
    }

    private var connect: Section {
        Section(id: "connect", title: "Connect your iPhone", systemImage: "cable.connector", steps: [
            Self.plugIn,
            "Roadivo's sound now plays through the car's speakers."
        ])
    }

    private var airPlay: Section {
        Section(id: "airplay", title: "AirPlay", systemImage: "airplayvideo", steps: [
            "Start a channel in Roadivo.",
            "Open Control Center, tap AirPlay and choose your car's display or adapter."
        ])
    }

    private var carMode: Section {
        Section(id: "carmode", title: "Car Mode", systemImage: "iphone.landscape", steps: [
            "Mount your iPhone on the dashboard.",
            "Once your iPhone is connected to the car, open Cast to Car and tap Start Car Mode."
        ])
    }

    private static let plugIn: LocalizedStringResource =
        "Plug your iPhone into the car's USB port. For wireless CarPlay, open Settings › General › CarPlay on your iPhone and choose your car."
}

// swiftlint:enable line_length
