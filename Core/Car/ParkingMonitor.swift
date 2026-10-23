import Foundation
import Observation

/// Where `ParkingMonitor` gets its readings: the iPhone's location, or a script in tests and Debug runs.
@MainActor
protocol MotionSampling: AnyObject {
    /// Location is off for Roadivo, so parked can never be known.
    var isLocationDenied: Bool { get }
    /// Shows iOS's question on the iPhone the first time; does nothing once it's answered.
    func requestAccess()
    func samples() -> AsyncStream<MotionSample>
}

/// Whether the car is parked, for video in Roadivo's CarPlay window (DECISIONS 152–153). Listens only while started.
@Observable
@MainActor
final class ParkingMonitor {
    private(set) var isParked = false
    /// The car's own word: CarPlay isn't limiting its keyboard, as cars do while moving. With Location on and no moving
    /// reading, that counts as parked at once; a moving reading still wins (DECISIONS 153).
    @ObservationIgnored var carAllowsFullInterface = false {
        didSet {
            if carAllowsFullInterface != oldValue {
                update()
            }
        }
    }

    /// Debug `-car-parked`: as if the car always said it's stopped, for testing at a desk. A moving reading still ends
    /// video, and Release builds never set it (DECISIONS 154).
    @ObservationIgnored var assumesParkedCar = false

    /// The latest reading, for the CarPlay trace and the car's word above.
    @ObservationIgnored private(set) var lastSample: MotionSample?
    @ObservationIgnored private(set) var lastSampleAt: Date?
    @ObservationIgnored private var detector: ParkingDetector
    @ObservationIgnored private let sampler: MotionSampling
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var listening: Task<Void, Never>?
    /// Wakes when a stop has lasted long enough to count as parked.
    @ObservationIgnored private var waiting: Task<Void, Never>?

    init(
        sampler: MotionSampling,
        parkedAfter: TimeInterval = ParkingDetector.defaultParkedAfter,
        now: @escaping () -> Date = Date.init
    ) {
        self.sampler = sampler
        self.now = now
        detector = ParkingDetector(parkedAfter: parkedAfter)
    }

    var isLocationDenied: Bool {
        sampler.isLocationDenied
    }

    func start() {
        guard listening == nil else { return }
        sampler.requestAccess()
        let samples = sampler.samples()
        listening = Task { [weak self] in
            for await sample in samples {
                self?.record(sample)
            }
            self?.record(.unknown) // The updates ended: parked can't be known any more.
        }
    }

    func stop() {
        listening?.cancel()
        listening = nil
        waiting?.cancel()
        waiting = nil
        detector.reset()
        lastSample = nil
        lastSampleAt = nil
        carAllowsFullInterface = false
        isParked = false
    }

    func record(_ sample: MotionSample) {
        lastSample = sample
        lastSampleAt = now()
        detector.record(sample, at: now())
        update()
    }

    private func update() {
        let carSaysParked = (carAllowsFullInterface || assumesParkedCar) && lastSample != .moving
            && !sampler.isLocationDenied
        let parked = carSaysParked || detector.isParked(at: now())
        if parked != isParked {
            isParked = parked
        }
        waiting?.cancel()
        waiting = nil
        guard !parked, let parkedAt = detector.parkedAt else { return }
        let delay = max(0, parkedAt.timeIntervalSince(now()))
        waiting = Task { [weak self] in
            // Cancelled when a new reading arrives; that reading decides instead.
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.update()
        }
    }
}
