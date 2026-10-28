import CarPlay
import OSLog

/// The CarPlay map's search (DECISIONS 147): Apple Maps' places near the car as the driver types. A chosen place
/// opens in Directions, which works out the routes the map then offers, on the iPhone too.
@MainActor
final class CarPlayPlaceSearch: NSObject, CPSearchTemplateDelegate {
    let template = CPSearchTemplate()
    private let directions: DirectionsViewModel
    private let finder: PlaceFinding
    /// Takes the driver back to the map, where the routes appear.
    private let onChoose: () -> Void
    private let logger = Logger(subsystem: "com.playcartv", category: "CarPlay")

    init(environment: AppEnvironment, onChoose: @escaping () -> Void) {
        directions = environment.directions
        finder = environment.places
        self.onChoose = onChoose
        super.init()
        template.delegate = self
    }

    func searchTemplate(
        _ searchTemplate: CPSearchTemplate,
        updatedSearchText searchText: String,
        completionHandler: @escaping ([CPListItem]) -> Void
    ) {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return completionHandler([]) }
        let near = directions.location.lastCoordinate
        Task { [finder, logger] in
            var places: [Place] = []
            do {
                places = try await finder.places(matching: text, near: near)
            } catch {
                logger.error("CarPlay search: \(error.localizedDescription, privacy: .public)")
            }
            completionHandler(places.isEmpty ? [Self.nothingFound()] : places.map(Self.row))
        }
    }

    func searchTemplate(
        _ searchTemplate: CPSearchTemplate,
        selectedResult item: CPListItem,
        completionHandler: @escaping () -> Void
    ) {
        if let place = item.userInfo as? Place {
            onChoose()
            Task { [directions] in await directions.choose(place, on: .car) }
        }
        completionHandler()
    }

    private static func row(_ place: Place) -> CPListItem {
        let item = CPListItem(
            text: place.name,
            detailText: place.address.isEmpty ? nil : place.address,
            image: UIImage(systemName: "mappin.circle.fill")
        )
        item.userInfo = place
        return item
    }

    private static func nothingFound() -> CPListItem {
        CPListItem(text: String(appLocalized: "No places found"), detailText: nil)
    }
}
