import Foundation
import Testing
@testable import PlayCarTV

@Suite("Paywall")
@MainActor
struct PaywallViewModelTests {
    private func make(_ client: FakeStoreClient = FakeStoreClient()) -> (PaywallViewModel, ProAccess) {
        let access = ProAccess(client: client)
        return (PaywallViewModel(access: access, reason: .intro), access)
    }

    @Test("Loads three plans with lifetime preselected")
    func load() async {
        let (viewModel, _) = make()
        await viewModel.load()
        #expect(viewModel.phase == .loaded)
        #expect(viewModel.offers.map(\.plan) == [.weekly, .yearly, .lifetime])
        #expect(viewModel.selected == .lifetime)
        #expect(viewModel.buyTitle == "Buy for ₹439")
        #expect(viewModel.terms.contains("No subscription"))
    }

    @Test("A subscriber sees their plan as current, can't buy it again, and can still upgrade")
    func currentPlan() async {
        let (viewModel, access) = make(FakeStoreClient(isPro: true)) // The fake Pro user has Yearly.
        await access.refresh()
        await viewModel.load()
        #expect(access.currentPlan == .yearly)
        #expect(viewModel.selected == .yearly) // Opens on the plan they have, not Lifetime.
        #expect(viewModel.isCurrent(.yearly))
        #expect(!viewModel.isCurrent(.lifetime))
        viewModel.selected = .yearly
        #expect(viewModel.isSelectedCurrent)
        #expect(viewModel.buyTitle == String(appLocalized: "Your current plan"))
        viewModel.selected = .lifetime
        #expect(!viewModel.isSelectedCurrent)
        #expect(viewModel.buyTitle == "Buy for ₹439")
    }

    @Test("Subscriptions show their renewal terms and intro price")
    func subscriptionCopy() async {
        let (viewModel, _) = make()
        await viewModel.load()
        viewModel.selected = .weekly
        #expect(viewModel.buyTitle == "Start for ₹20")
        #expect(viewModel.terms.contains("Renews automatically"))
    }

    @Test("Per-week price uses the storefront's format and only applies to yearly")
    func perWeek() {
        let usd = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))
        #expect(PlanOffer.perWeek(.yearly, price: 45.99, format: usd) == "$0.88")
        #expect(PlanOffer.perWeek(.weekly, price: 3.99, format: usd) == nil)
        let inr = Decimal.FormatStyle.Currency(code: "INR", locale: Locale(identifier: "en_IN"))
        // ICU's en_IN style puts a space after the symbol; keep whatever the storefront uses.
        let rupees = PlanOffer.perWeek(.yearly, price: 939, format: inr)
        #expect(rupees?.hasPrefix("₹") == true)
        #expect(rupees?.hasSuffix("18.06") == true)
    }

    @Test("Buying unlocks Pro")
    func buy() async {
        let client = FakeStoreClient()
        let (viewModel, access) = make(client)
        await viewModel.load()
        viewModel.selected = .yearly
        #expect(await viewModel.buy())
        #expect(access.isPro)
        #expect(client.purchased == [.yearly])
    }

    @Test("Cancelling or pending leaves the user on Free")
    func notBought() async {
        let (cancelled, cancelledAccess) = make(FakeStoreClient(outcome: .cancelled))
        await cancelled.load()
        #expect(await !cancelled.buy())
        #expect(!cancelledAccess.isPro)
        #expect(cancelled.message == nil)

        let (pending, _) = make(FakeStoreClient(outcome: .pending))
        await pending.load()
        #expect(await !pending.buy())
        #expect(pending.message?.contains("waiting for approval") == true)
    }

    @Test("Restore reports when nothing was bought, and unlocks when it was")
    func restore() async {
        let (none, _) = make()
        #expect(await !none.restore())
        #expect(none.message?.contains("No active PlayCarTV Pro purchase") == true)

        let (owned, access) = make(FakeStoreClient(isPro: true))
        #expect(await owned.restore())
        #expect(access.isPro)
    }

    @Test("Restore brings back a purchase made earlier, and names its plan")
    func restoreBringsBackEarlierPurchase() async {
        let (viewModel, access) = make(FakeStoreClient(restorable: [.yearly]))
        await access.refresh()
        #expect(!access.isPro)
        #expect(await viewModel.restore())
        #expect(access.currentPlan == .yearly)
        #expect(viewModel.message == nil)
    }

    @Test("Closing the Apple Account sign-in during Restore shows nothing")
    func restoreCancelled() async {
        let (viewModel, access) = make(FakeStoreClient(restoreCancels: true))
        #expect(await !viewModel.restore())
        #expect(viewModel.message == nil)
        #expect(!access.isPro)
    }

    @Test("A store failure shows a retryable error")
    func failure() async {
        let (viewModel, _) = make(FakeStoreClient(failure: .productUnavailable))
        await viewModel.load()
        #expect(viewModel.phase == .failed(StoreError.productUnavailable.localizedDescription))
    }
}
