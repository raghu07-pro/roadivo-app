import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)

    /// The "Asphalt" asset catalog color resource.
    static let asphalt = DeveloperToolsSupport.ColorResource(name: "Asphalt", bundle: resourceBundle)

    /// The "CanvasBackground" asset catalog color resource.
    static let canvasBackground = DeveloperToolsSupport.ColorResource(name: "CanvasBackground", bundle: resourceBundle)

    /// The "LaneYellow" asset catalog color resource.
    static let laneYellow = DeveloperToolsSupport.ColorResource(name: "LaneYellow", bundle: resourceBundle)

    /// The "LaunchBackground" asset catalog color resource.
    static let launchBackground = DeveloperToolsSupport.ColorResource(name: "LaunchBackground", bundle: resourceBundle)

    /// The "LiveRed" asset catalog color resource.
    static let liveRed = DeveloperToolsSupport.ColorResource(name: "LiveRed", bundle: resourceBundle)

    /// The "SurfaceBackground" asset catalog color resource.
    static let surfaceBackground = DeveloperToolsSupport.ColorResource(name: "SurfaceBackground", bundle: resourceBundle)

    /// The "SurfaceElevated" asset catalog color resource.
    static let surfaceElevated = DeveloperToolsSupport.ColorResource(name: "SurfaceElevated", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

}

