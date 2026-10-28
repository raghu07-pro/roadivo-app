import Foundation
import Testing
@testable import PlayCarTV

/// Video in PlayCarTV's CarPlay window shows only while parked (DECISIONS 152).
@Suite("Parking")
@MainActor
struct ParkingTests {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    // MARK: Readings

    @Test("Any speed from 0.5 m/s counts as moving, even if Core Location says still")
    func movingWins() {
        #expect(MotionSample.classify(speed: 0.5, speedAccuracy: 0.3, isStationary: false) == .moving)
        #expect(MotionSample.classify(speed: 12, speedAccuracy: -1, isStationary: true) == .moving)
    }

    @Test("A slow, precise speed or Core Location's stationary verdict counts as still")
    func stillReadings() {
        #expect(MotionSample.classify(speed: 0, speedAccuracy: 0.5, isStationary: false) == .still)
        #expect(MotionSample.classify(speed: 0.4, speedAccuracy: 2, isStationary: false) == .still)
        #expect(MotionSample.classify(speed: nil, speedAccuracy: nil, isStationary: true) == .still)
    }

    @Test("No fix, an unknown speed or a vague one can't tell, so it isn't still")
    func unknownReadings() {
        #expect(MotionSample.classify(speed: nil, speedAccuracy: nil, isStationary: false) == .unknown)
        #expect(MotionSample.classify(speed: -1, speedAccuracy: 1, isStationary: false) == .unknown)
        #expect(MotionSample.classify(speed: 0, speedAccuracy: -1, isStationary: false) == .unknown)
        #expect(MotionSample.classify(speed: 0.2, speedAccuracy: 3, isStationary: false) == .unknown)
    }

    // MARK: Detector

    @Test("Parked only after 30 s of still readings in a row")
    func parkedAfterThirtySeconds() {
        var detector = ParkingDetector()
        #expect(!detector.isParked(at: start))
        detector.record(.still, at: start)
        detector.record(.still, at: start.addingTimeInterval(10)) // A later still reading doesn't restart the wait.
        #expect(!detector.isParked(at: start.addingTimeInterval(29.9)))
        #expect(detector.isParked(at: start.addingTimeInterval(30)))
        #expect(detector.parkedAt == start.addingTimeInterval(30))
    }

    @Test("Moving or an unknown reading ends parked at once and restarts the wait")
    func movingEndsParked() {
        for interruption in [MotionSample.moving, .unknown] {
            var detector = ParkingDetector()
            detector.record(.still, at: start)
            #expect(detector.isParked(at: start.addingTimeInterval(60)))
            detector.record(interruption, at: start.addingTimeInterval(61))
            #expect(!detector.isParked(at: start.addingTimeInterval(61)))
            #expect(detector.parkedAt == nil)
            detector.record(.still, at: start.addingTimeInterval(62))
            #expect(!detector.isParked(at: start.addingTimeInterval(91)))
            #expect(detector.isParked(at: start.addingTimeInterval(92)))
        }
    }

    @Test("Reset forgets the stop")
    func resetForgets() {
        var detector = ParkingDetector()
        detector.record(.still, at: start)
        detector.reset()
        #expect(!detector.isParked(at: start.addingTimeInterval(120)))
    }

    // MARK: Monitor

    @Test("The monitor parks after the wait and unparks the moment the car moves")
    func monitorFollowsReadings() {
        var clock = start
        let monitor = ParkingMonitor(sampler: SilentSampler(), parkedAfter: 0, now: { clock })
        #expect(!monitor.isParked)
        monitor.record(.still)
        #expect(monitor.isParked)
        clock = start.addingTimeInterval(5)
        monitor.record(.moving)
        #expect(!monitor.isParked)
    }

    @Test("Stopping the monitor forgets the stop")
    func monitorStopForgets() {
        let monitor = ParkingMonitor(sampler: SilentSampler(), parkedAfter: 0)
        monitor.record(.still)
        #expect(monitor.isParked)
        monitor.stop()
        #expect(!monitor.isParked)
    }

    @Test("The car's unlocked keyboard counts as parked at once, until a reading says the car is moving")
    func carSignalParks() {
        let monitor = ParkingMonitor(sampler: SilentSampler())
        monitor.carAllowsFullInterface = true
        #expect(monitor.isParked)
        monitor.record(.unknown) // Indoors or in a garage: no speed, but the car's word stands.
        #expect(monitor.isParked)
        monitor.record(.moving)
        #expect(!monitor.isParked)
        monitor.record(.still)
        #expect(monitor.isParked)
        monitor.carAllowsFullInterface = false
        #expect(!monitor.isParked, "Back to 30 s of still readings")
    }

    @Test("Without Location, the car's word alone isn't enough")
    func carSignalNeedsLocation() {
        let monitor = ParkingMonitor(sampler: SilentSampler(isLocationDenied: true))
        monitor.carAllowsFullInterface = true
        #expect(!monitor.isParked)
    }

    @Test("Debug -car-parked counts as parked at a desk, but a moving reading still ends it")
    func assumedParkedCar() {
        let monitor = ParkingMonitor(sampler: SilentSampler())
        monitor.assumesParkedCar = true
        monitor.record(.unknown)
        #expect(monitor.isParked)
        monitor.record(.moving)
        #expect(!monitor.isParked)
    }

    @Test("Debug -car-parked counts from the moment the car connects, again after reconnecting, with no reading")
    func assumedParkedCarWithoutReadings() {
        let monitor = ParkingMonitor(sampler: SilentSampler())
        monitor.assumesParkedCar = true
        monitor.start()
        #expect(monitor.isParked)
        monitor.stop()
        #expect(!monitor.isParked)
        monitor.start()
        #expect(monitor.isParked)
        monitor.stop()
    }

    @Test("The desk switch shows video without Location too; a moving reading still ends it")
    func assumedParkedCarWithoutLocation() {
        let monitor = ParkingMonitor(sampler: SilentSampler(isLocationDenied: true))
        monitor.assumesParkedCar = true
        monitor.start()
        #expect(!monitor.isLocationDenied)
        #expect(monitor.isParked)
        monitor.record(.moving)
        #expect(!monitor.isParked)
        monitor.stop()
    }

    @Test("Stopping forgets the car's word too")
    func stopForgetsCarSignal() {
        let monitor = ParkingMonitor(sampler: SilentSampler())
        monitor.carAllowsFullInterface = true
        monitor.stop()
        #expect(!monitor.carAllowsFullInterface)
        #expect(!monitor.isParked)
    }

    @Test("Location off for PlayCarTV is passed on from the sampler")
    func monitorReportsLocationOff() {
        #expect(ParkingMonitor(sampler: SilentSampler(isLocationDenied: true)).isLocationDenied)
        #expect(!ParkingMonitor(sampler: SilentSampler()).isLocationDenied)
    }

    // MARK: Window

    @Test("The window: Pro first, then what's playing, then Location, then parked")
    func windowStates() {
        func state(
            pro: Bool = true,
            playing: Bool = true,
            parked: Bool = true,
            denied: Bool = false
        ) -> CarWindowState {
            CarWindowState.make(isPro: pro, isPlaying: playing, isParked: parked, isLocationDenied: denied)
        }
        #expect(state(pro: false) == .upgrade)
        #expect(state(playing: false) == .home)
        #expect(state(playing: false, denied: true) == .home)
        #expect(state(denied: true) == .needsLocation)
        #expect(state() == .video)
        #expect(state(parked: false) == .driving)
    }

    @Test("The tabs show only while nothing plays")
    func tabsOnlyAtHome() {
        #expect(CarWindowState.home.showsTabs)
        for state in [CarWindowState.upgrade, .video, .driving, .needsLocation] {
            #expect(!state.showsTabs)
        }
    }

    @Test("Every state but the video has a line to show; the video has none")
    func windowMessages() {
        for state in [CarWindowState.upgrade, .home, .driving, .needsLocation] {
            #expect(CarWindowCard.Content(state: state).message?.isEmpty == false)
        }
        #expect(CarWindowCard.Content(state: .video).message == nil)
        #expect(CarWindowCard.Content(state: .driving, title: "News").heading == "News")
    }
}

/// A sampler with no readings, for driving the monitor by hand.
@MainActor
private final class SilentSampler: MotionSampling {
    let isLocationDenied: Bool

    init(isLocationDenied: Bool = false) {
        self.isLocationDenied = isLocationDenied
    }

    func requestAccess() {}

    func samples() -> AsyncStream<MotionSample> {
        AsyncStream { _ in }
    }
}
