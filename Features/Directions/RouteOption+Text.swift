import Foundation

extension RouteOption {
    /// "1 hr 5 min", in the app's language; never under a minute.
    func travelTimeText(locale: Locale) -> String {
        Duration.seconds(max(travelTime, 60).rounded())
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
    }

    /// "54 km" or "34 mi", as the region measures roads.
    func distanceText(locale: Locale) -> String {
        Measurement(value: distance, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road).locale(locale))
    }
}
