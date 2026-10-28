import StoreKitTest
import Testing
@testable import PlayCarTV

/// Loads StoreKit/PlayCarTV.storekit through Apple's test session and the real `StoreKitClient`, so a
/// malformed file or product-ID typo fails here, not as "Plans aren't available".
@Suite("StoreKit configuration", .serialized)
@MainActor
struct StoreKitConfigurationTests {
    @Test("All three plans load with prices, intro offer and per-week price")
    func loadsPlans() async throws {
        let session = try SKTestSession(configurationFileNamed: "PlayCarTV")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions() // The first-week price is only for someone who never subscribed.

        let offers = try await StoreKitClient().offers()

        #expect(offers.map(\.plan) == [.weekly, .yearly, .lifetime])
        #expect(offers.first { $0.plan == .weekly }?.introPrice != nil)
        #expect(offers.first { $0.plan == .yearly }?.perWeekPrice != nil)
        #expect(offers.allSatisfy { !$0.displayPrice.isEmpty })
    }

    @Test("Buying lifetime grants Pro")
    func purchase() async throws {
        let session = try SKTestSession(configurationFileNamed: "PlayCarTV")
        session.resetToDefaultState()
        session.disableDialogs = true
        let client = StoreKitClient()
        try await clearPurchases(in: session, seenBy: client)

        #expect(await !client.hasActiveEntitlement())
        #expect(try await client.purchase(.lifetime) == .purchased)
        #expect(await client.hasActiveEntitlement())
    }

    /// An earlier run's lifetime purchase outlives `clearTransactions()` for a moment: StoreKit's entitlements
    /// catch up after the session. Each is deleted, then the client is given up to 5 s to stop seeing them.
    private func clearPurchases(in session: SKTestSession, seenBy client: StoreKitClient) async throws {
        for transaction in session.allTransactions() {
            try session.deleteTransaction(identifier: transaction.identifier)
        }
        session.clearTransactions()
        let deadline = ContinuousClock.now + .seconds(5)
        while await client.hasActiveEntitlement(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100)) // Polls the condition; the deadline bounds it.
        }
    }
}
