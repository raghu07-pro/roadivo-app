import Foundation

/// The three ways to buy Roadivo Pro. Product IDs must match App Store Connect.
enum ProPlan: String, CaseIterable, Identifiable, Sendable {
    case weekly
    case yearly
    case lifetime

    var id: String {
        rawValue
    }

    /// Placeholder prefix until the real bundle ID is set (DECISIONS 2).
    var productID: String {
        "com.example.roadivo.pro.\(rawValue)"
    }

    static var productIDs: Set<String> {
        Set(allCases.map(\.productID))
    }

    var isSubscription: Bool {
        self != .lifetime
    }

    var title: LocalizedStringResource {
        switch self {
        case .weekly: "Weekly"
        case .yearly: "Yearly"
        case .lifetime: "Lifetime"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .weekly: "Flexible, cancel anytime"
        case .yearly: "Billed once a year, cancel anytime"
        case .lifetime: "One-time purchase, lifetime access"
        }
    }
}

/// A plan as the store currently prices it for this user.
struct PlanOffer: Identifiable, Equatable, Sendable {
    let plan: ProPlan
    let displayPrice: String
    let price: Decimal
    /// The introductory price, only when this user is eligible for it.
    let introPrice: String?
    /// The yearly price per week ("₹18.06"), formatted in the storefront's
    /// style, not the device's: the two differ (an Indian storefront on a US
    /// device, a locale that writes "$ 0.88").
    let perWeekPrice: String?

    var id: ProPlan {
        plan
    }

    /// A price-less stand-in for layout while loading or when the store is unreachable.
    static func placeholder(_ plan: ProPlan) -> PlanOffer {
        PlanOffer(plan: plan, displayPrice: "—", price: 0, introPrice: nil, perWeekPrice: nil)
    }

    static func perWeek(_ plan: ProPlan, price: Decimal, format: Decimal.FormatStyle.Currency) -> String? {
        plan == .yearly ? (price / 52).formatted(format) : nil
    }
}

enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    case cancelled
    /// Waiting on Ask to Buy or a payment check.
    case pending
}

enum StoreError: LocalizedError, Equatable {
    case productUnavailable
    case unverified

    var errorDescription: String? {
        switch self {
        case .productUnavailable: String(appLocalized: "That plan isn't available right now. Try again later.")
        case .unverified: String(appLocalized: "The App Store couldn't verify this purchase.")
        }
    }
}

/// Everything the app needs from the App Store. A protocol so tests and UI
/// tests never touch StoreKit.
protocol StoreClient: Sendable {
    func offers() async throws -> [PlanOffer]
    func purchase(_ plan: ProPlan) async throws -> PurchaseOutcome
    func restore() async throws
    func hasActiveEntitlement() async -> Bool
    /// Fires whenever a transaction arrives from outside the app (renewal,
    /// refund, Ask to Buy approval, another device).
    func entitlementUpdates() -> AsyncStream<Void>
}
