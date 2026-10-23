import Foundation

/// Whether the iPhone shows Directions: `ROADIVO_DIRECTIONS` in `Config/Shared.xcconfig`. Off for now, with the code
/// kept for a later release (DECISIONS 149).
enum DirectionsAvailability {
    static var isEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "ROADIVO_DIRECTIONS") as? String) == "YES"
    }
}
