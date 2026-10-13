import StoreKitTest
import Testing
@testable import Roadivo

/// Loads StoreKit/Roadivo.storekit through Apple's test session and the real
/// `StoreKitClient`, so a malformed file or a product-ID typo fails here
/// instead of showing "Plans aren't available" in the simulator.
@Suite("StoreKit configuration", .serialized)
@MainActor
struct StoreKitConfigurationTests {
    @Test("All three plans load with prices, intro offer and per-week price")
    func loadsPlans() async throws {
        let session = try SKTestSession(configurationFileNamed: "Roadivo")
        session.resetToDefaultState()
        session.disableDialogs = true

        let offers = try await StoreKitClient().offers()

        #expect(offers.map(\.plan) == [.weekly, .yearly, .lifetime])
        #expect(offers.first { $0.plan == .weekly }?.introPrice != nil)
        #expect(offers.first { $0.plan == .yearly }?.perWeekPrice != nil)
        #expect(offers.allSatisfy { !$0.displayPrice.isEmpty })
    }

    @Test("Buying lifetime grants Pro")
    func purchase() async throws {
        let session = try SKTestSession(configurationFileNamed: "Roadivo")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()

        let client = StoreKitClient()
        #expect(await !client.hasActiveEntitlement())
        #expect(try await client.purchase(.lifetime) == .purchased)
        #expect(await client.hasActiveEntitlement())
    }
}
