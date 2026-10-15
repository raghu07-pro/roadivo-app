import Foundation

/// In-memory store for unit tests, previews and UI-test launches
/// (`-ui-testing`). Prices mirror the local StoreKit configuration.
final class FakeStoreClient: StoreClient, @unchecked Sendable {
    private let lock = NSLock()
    private var plans: Set<ProPlan>
    private let outcome: PurchaseOutcome
    private let failure: StoreError?
    private(set) var purchased: [ProPlan] = []

    static let sampleOffers: [PlanOffer] = [
        PlanOffer(plan: .weekly, displayPrice: "$3.99", price: 3.99, introPrice: "$0.99", perWeekPrice: nil),
        PlanOffer(plan: .yearly, displayPrice: "$45.99", price: 45.99, introPrice: nil, perWeekPrice: "$0.88"),
        PlanOffer(plan: .lifetime, displayPrice: "$21.49", price: 21.49, introPrice: nil, perWeekPrice: nil)
    ]

    init(isPro: Bool = false, outcome: PurchaseOutcome = .purchased, failure: StoreError? = nil) {
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
    }

    func activePlans() async -> Set<ProPlan> {
        lock.withLock { plans }
    }

    func entitlementUpdates() -> AsyncStream<Void> {
        AsyncStream { _ in }
    }
}
