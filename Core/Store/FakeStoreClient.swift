import Foundation

/// In-memory store for unit tests, previews and UI-test launches
/// (`-ui-testing`). Prices mirror the local StoreKit configuration.
final class FakeStoreClient: StoreClient, @unchecked Sendable {
    private let lock = NSLock()
    private var plans: Set<ProPlan>
    /// Bought earlier on this Apple Account: appears only once Restore syncs with the "App Store".
    private let restorable: Set<ProPlan>
    /// Restore behaves as if the user closed the Apple Account sign-in.
    private let restoreCancels: Bool
    private let outcome: PurchaseOutcome
    private let failure: StoreError?
    private(set) var purchased: [ProPlan] = []

    static let sampleOffers: [PlanOffer] = [
        PlanOffer(plan: .weekly, displayPrice: "₹80", price: 80, introPrice: "₹20", perWeekPrice: nil),
        PlanOffer(plan: .yearly, displayPrice: "₹939", price: 939, introPrice: nil, perWeekPrice: "₹18.06"),
        PlanOffer(plan: .lifetime, displayPrice: "₹439", price: 439, introPrice: nil, perWeekPrice: nil)
    ]

    init(
        isPro: Bool = false,
        restorable: Set<ProPlan> = [],
        restoreCancels: Bool = false,
        outcome: PurchaseOutcome = .purchased,
        failure: StoreError? = nil
    ) {
        self.restorable = restorable
        self.restoreCancels = restoreCancels
        plans = isPro ? [.yearly] : [] // A subscriber, so Settings offers Manage Subscription.
        self.outcome = outcome
        self.failure = failure
    }

    func offers() async throws -> [PlanOffer] {
        if let failure {
            throw failure
        }
        return Self.sampleOffers
    }

    func purchase(_ plan: ProPlan) async throws -> PurchaseOutcome {
        if let failure {
            throw failure
        }
        lock.withLock {
            purchased.append(plan)
            if outcome == .purchased {
                plans.insert(plan)
            }
        }
        return outcome
    }

    func restore() async throws {
        if let failure {
            throw failure
        }
        if restoreCancels {
            throw CancellationError()
        }
        lock.withLock { plans.formUnion(restorable) }
    }

    func activePlans() async -> Set<ProPlan> {
        lock.withLock { plans }
    }

    func entitlementUpdates() -> AsyncStream<Void> {
        AsyncStream { _ in }
    }
}
