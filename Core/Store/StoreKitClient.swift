import Foundation
import StoreKit

/// StoreKit 2 implementation of `StoreClient`.
struct StoreKitClient: StoreClient {
    func offers() async throws -> [PlanOffer] {
        let products = try await Product.products(for: ProPlan.productIDs)
        var offers: [PlanOffer] = []
        for plan in ProPlan.allCases {
            guard let product = products.first(where: { $0.id == plan.productID }) else { continue }
            var intro: String?
            if let subscription = product.subscription, let offer = subscription.introductoryOffer,
               await subscription.isEligibleForIntroOffer {
                intro = offer.displayPrice
            }
            offers.append(PlanOffer(
                plan: plan,
                displayPrice: product.displayPrice,
                price: product.price,
                introPrice: intro,
                perWeekPrice: PlanOffer.perWeek(plan, price: product.price, format: product.priceFormatStyle)
            ))
        }
        return offers
    }

    func purchase(_ plan: ProPlan) async throws -> PurchaseOutcome {
        guard let product = try await Product.products(for: [plan.productID]).first else {
            throw StoreError.productUnavailable
        }
        switch try await product.purchase() {
        case let .success(verification):
            guard case let .verified(transaction) = verification else { throw StoreError.unverified }
            await transaction.finish()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restore() async throws {
        try await AppStore.sync()
    }

    func hasActiveEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  ProPlan.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry < .now {
                continue
            }
            return true
        }
        return false
    }

    func entitlementUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if case let .verified(transaction) = result {
                        await transaction.finish()
                    }
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
