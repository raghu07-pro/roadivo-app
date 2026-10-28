import Foundation
import Testing
@testable import PlayCarTV

@Suite("Pro access")
@MainActor
struct ProAccessTests {
    @Test("A verified purchase unlocks Pro and closes the paywall even if the entitlement list lags")
    func purchaseCountsAtOnce() async {
        let access = ProAccess(client: LaggingStore())
        let paywall = PaywallViewModel(access: access, reason: .intro)
        await paywall.load()
        paywall.selected = .weekly
        #expect(await paywall.buy())
        #expect(access.isPro)
        #expect(access.currentPlan == .weekly)
        #expect(paywall.isCurrent(.weekly))
    }

    @Test("Once the App Store lists the plan, its list is the only source again")
    func storeTakesOver() async {
        let store = LaggingStore()
        let access = ProAccess(client: store)
        access.recordPurchase(.yearly)
        store.listed = [.yearly]
        await access.refresh()
        #expect(access.currentPlan == .yearly)
        store.listed = [] // Refunded later.
        await access.refresh()
        #expect(!access.isPro)
    }
}

/// An App Store whose entitlement list doesn't show a purchase until told to.
private final class LaggingStore: StoreClient, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Set<ProPlan> = []

    var listed: Set<ProPlan> {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }

    func offers() async throws -> [PlanOffer] {
        FakeStoreClient.sampleOffers
    }

    func purchase(_ plan: ProPlan) async throws -> PurchaseOutcome {
        .purchased
    }

    func restore() async throws {}

    func activePlans() async -> Set<ProPlan> {
        listed
    }

    func entitlementUpdates() -> AsyncStream<Void> {
        AsyncStream { _ in }
    }
}
