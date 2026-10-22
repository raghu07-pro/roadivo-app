import Foundation

/// One instruction of a route as Apple Maps gives it: what to do where this stretch starts, then the stretch.
struct RouteStep: Equatable, Sendable {
    /// "Turn right onto Rua Augusta", in the iPhone's language; Maps leaves the first one empty.
    let instructions: String
    /// In metres.
    let distance: Double
    let path: [Coordinate]
}
