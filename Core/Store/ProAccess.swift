import Foundation
import Observation

/// Whether this user has Roadivo Pro. Free: one source (plus videos on this
/// iPhone). Pro: unlimited sources and Car Mode (DECISIONS 22).
@Observable
@MainActor
final class ProAccess {
    private(set) var isPro = false
    let client: StoreClient
    @ObservationIgnored private var listener: Task<Void, Never>?

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
        isPro = await client.hasActiveEntitlement()
    }
}
