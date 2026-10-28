import Foundation

/// Whether the iPhone shows Directions: `PLAYCARTV_DIRECTIONS` in `Config/Shared.xcconfig`. Off for now, with the code
/// kept for a later release (DECISIONS 149).
enum DirectionsAvailability {
    static var isEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "PLAYCARTV_DIRECTIONS") as? String) == "YES"
    }
}
