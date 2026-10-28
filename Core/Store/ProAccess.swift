import Foundation
import Observation

/// Whether this user has PlayCarTV Pro. Free: one source (plus videos on this
/// iPhone). Pro: unlimited sources and Car Mode (DECISIONS 22).
@Observable
@MainActor
final class ProAccess {
    /// What the App Store lists, plus a plan just bought here that it may not list yet.
    var activePlans: Set<ProPlan> {
        storePlans.union(justBought)
    }

    private var storePlans: Set<ProPlan> = []
    /// A verified purchase counts at once; right after buying, the App Store's list can lag behind.
    private var justBought: Set<ProPlan> = []
    let client: StoreClient
    @ObservationIgnored private var listener: Task<Void, Never>?

    var isPro: Bool {
        !activePlans.isEmpty
    }

    /// The plan Settings shows: Lifetime over Yearly over Weekly when several are active.
    var currentPlan: ProPlan? {
        [ProPlan.lifetime, .yearly, .weekly].first { activePlans.contains($0) }
    }

    /// A renewing plan is active (so Settings offers Manage Subscription), even alongside Lifetime.
    var hasSubscription: Bool {
        activePlans.contains { $0.isSubscription }
    }

    /// Sources a free user may add before the paywall appears.
    static let freeSourceLimit = 1

    init(client: StoreClient) {
        self.client = client
    }

    /// Reads the current entitlement, then follows transaction updates.
    func start() {
        guard listener == nil else { return }
        let client = client
        listener = Task { [weak self] in
            await self?.refresh()
            for await _ in client.entitlementUpdates() {
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        storePlans = await client.activePlans()
        justBought.subtract(storePlans) // Listed now, so refunds and expiry are the App Store's to report.
    }

    /// Called after a purchase StoreKit has verified.
    func recordPurchase(_ plan: ProPlan) {
        justBought.insert(plan)
    }
}
