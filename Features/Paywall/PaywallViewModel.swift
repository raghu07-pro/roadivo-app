import Foundation
import Observation

@Observable
@MainActor
final class PaywallViewModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    let reason: PaywallReason
    private(set) var phase: Phase = .loading
    private(set) var offers: [PlanOffer] = []
    /// The plan the user already has, or Lifetime (as in the reference flow).
    var selected: ProPlan = .lifetime
    private(set) var isPurchasing = false
    var message: String?

    private let access: ProAccess

    init(access: ProAccess, reason: PaywallReason) {
        self.access = access
        self.reason = reason
    }

    var selectedOffer: PlanOffer? {
        offers.first { $0.plan == selected }
    }

    var isPro: Bool {
        access.isPro
    }

    /// Plans this Apple Account already has, marked "Current plan" and not for sale again.
    func isCurrent(_ plan: ProPlan) -> Bool {
        access.activePlans.contains(plan)
    }

    var isSelectedCurrent: Bool {
        isCurrent(selected)
    }

    var buyTitle: String {
        guard let offer = selectedOffer else { return String(appLocalized: "Continue") }
        if isSelectedCurrent {
            return String(appLocalized: "Your current plan")
        }
        if offer.plan.isSubscription, let intro = offer.introPrice {
            return String(appLocalized: "Start for \(intro)")
        }
        return offer.plan.isSubscription
            ? String(appLocalized: "Subscribe for \(offer.displayPrice)")
            : String(appLocalized: "\(offer.displayPrice) Buy now")
    }

    /// The legal line under the plans; App Review requires the renewal terms.
    var terms: String {
        guard let offer = selectedOffer else { return "" }
        switch offer.plan {
        case .lifetime:
            return String(appLocalized: "Pay once, keep forever. No subscription, no renewals.")
        case .weekly:
            // Whole sentences, so translators can reorder them.
            let price = offer.introPrice.map { intro in
                String(appLocalized: "First week \(intro), then \(offer.displayPrice) a week.")
            } ?? String(appLocalized: "\(offer.displayPrice) a week.")
            return price + " " + Self.renewal
        case .yearly:
            return String(appLocalized: "\(offer.displayPrice) a year.") + " " + Self.renewal
        }
    }

    private static var renewal: String {
        String(appLocalized: "Renews automatically; cancel anytime in Settings › Apple Account › Subscriptions.")
    }

    func load() async {
        phase = .loading
        do {
            offers = try await access.client.offers()
            if let current = access.currentPlan, offers.contains(where: { $0.plan == current }) {
                selected = current
            } else if !offers.contains(where: { $0.plan == selected }), let first = offers.last {
                selected = first.plan
            }
            phase = offers.isEmpty
                ?
                .failed(
                    String(appLocalized: "Plans aren't available right now. Check your connection and try again.")
                )
                : .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Returns true when Pro is unlocked.
    func buy() async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }
        do {
            switch try await access.client.purchase(selected) {
            case .purchased:
                // Verified by StoreKit: Pro now, whether or not the entitlement list has caught up.
                access.recordPurchase(selected)
                await access.refresh()
                return true
            case .pending:
                message =
                    String(appLocalized: "Your purchase is waiting for approval. Pro unlocks as soon as it's approved.")
                return false
            case .cancelled:
                return false
            }
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    /// Returns true when a previous purchase was found.
    func restore() async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }
        do {
            try await access.client.restore()
        } catch is CancellationError {
            return false // The user closed the Apple Account sign-in.
        } catch {
            message = error.localizedDescription
            return false
        }
        await access.refresh()
        if !access.isPro {
            message = String(appLocalized: "No active Roadivo Pro purchase was found for this Apple Account.")
        }
        return access.isPro
    }
}
