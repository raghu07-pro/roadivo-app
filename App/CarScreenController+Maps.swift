#if DEBUG
    import UIKit

    /// The Maps tab's search (DECISIONS 172): the car types its own, and a place chosen there is the iPhone's too.
    extension CarScreenController {
        func showPlaceSearch() {
            field = nil
            model.searchText = ""
            model.searchInput = .choose
            model.placeSearch = .idle
            let title = String(appLocalized: "Search for a place")
            show(.search(.init(title: title, isSearch: true, isField: false, scope: nil, isPlace: true)))
        }

        /// The page stays while Maps finds the place, so a failure shows there; then Maps shows its routes.
        func choosePlace(_ suggestion: PlaceSuggestion) {
            guard let directions = model.directions else { return }
            Task {
                await directions.choose(suggestion, on: .car) { search in
                    model.placeSearch = search
                    if search == .idle {
                        closePage()
                        model.tab = .maps
                    }
                }
            }
        }

        /// Show on iPhone: the route leaves the car for the iPhone's Maps, as Play on iPhone moves a video.
        func showRouteOnPhone() {
            model.directions?.move(to: .phone)
            AppEnvironment.current?.router.selectedTab = .directions
        }

        /// Show on Car Display, from the iPhone: Maps opens here, as a video sent to the car plays.
        func followRoute() {
            guard let directions = model.directions else { return }
            let arrived = directions.screen == .car && routeScreen != .car
            routeScreen = directions.screen
            if arrived, directions.destination != nil {
                model.tab = .maps
            }
        }

        /// The search key, or the end of Voice Input: the first place found, once there is one.
        func submitPlaceSearch() {
            guard case let .found(places) = model.placeSearch, let first = places.first else { return }
            choosePlace(first)
        }
    }
#endif
