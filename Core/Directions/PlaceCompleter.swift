import MapKit

/// Apple Maps' autocomplete (`MKLocalSearchCompleter`), awaited: several places for a few letters or a misspelling,
/// where a plain search answers with its one best match (owner, 2026-10-27; DECISIONS 172).
@MainActor
final class PlaceCompleter: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var waiting: CheckedContinuation<[PlaceSuggestion], Error>?
    private let limit: Int

    init(limit: Int) {
        self.limit = limit
        super.init()
        completer.delegate = self
        // Places and addresses only, not "coffee near me"-style searches, which have no single spot to route to.
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func suggestions(matching query: String, near: Coordinate?, radius: CLLocationDistance) async throws
        -> [PlaceSuggestion] {
        // A newer search replaces one still waiting, which its caller has already given up on.
        waiting?.resume(throwing: CancellationError())
        waiting = nil
        if let near {
            completer.region = MKCoordinateRegion(
                center: near.location,
                latitudinalMeters: radius,
                longitudinalMeters: radius
            )
        }
        // The same text again (Try Again) gets no new answer from the completer: its last one stands.
        if completer.queryFragment == query, !completer.isSearching {
            return current
        }
        return try await withCheckedThrowingContinuation { continuation in
            waiting = continuation
            completer.queryFragment = query
        }
    }

    private var current: [PlaceSuggestion] {
        completer.results.prefix(limit).map { PlaceSuggestion(title: $0.title, subtitle: $0.subtitle) }
    }

    private func finish(_ result: Result<[PlaceSuggestion], Error>) {
        waiting?.resume(with: result)
        waiting = nil
    }

    nonisolated func completerDidUpdateResults(_: MKLocalSearchCompleter) {
        Task { @MainActor in finish(.success(current)) }
    }

    nonisolated func completer(_: MKLocalSearchCompleter, didFailWithError error: Error) {
        let nothingFound = (error as? MKError)?.code == .placemarkNotFound
        Task { @MainActor in finish(nothingFound ? .success([]) : .failure(error)) }
    }
}
