import SwiftUI
import UIKit

/// The app's lettering, from Settings › Theme. Every style keeps Dynamic Type's text styles, so
/// text still grows with the iPhone's text size.
enum ThemeFont: String, CaseIterable, Identifiable {
    /// Overpass headings (modelled on highway signs) with SF Pro for reading: the brand's look.
    case roadSign
    case standard
    case rounded
    case serif

    static let `default`: ThemeFont = .roadSign

    var id: String {
        rawValue
    }

    var title: LocalizedStringResource {
        switch self {
        case .roadSign: "Road Sign"
        case .standard: "Standard"
        case .rounded: "Rounded"
        case .serif: "Serif"
        }
    }

    /// The system design for this style; Road Sign uses it for reading text only.
    var design: Font.Design {
        switch self {
        case .roadSign, .standard: .default
        case .rounded: .rounded
        case .serif: .serif
        }
    }

    /// For every system font in the app (set at the root): plain text follows the style too. Road
    /// Sign leaves SF Pro as it is.
    var rootDesign: Font.Design? {
        self == .roadSign ? nil : design
    }

    /// The option row's "Aa" and name, always in this style whatever is chosen now.
    var preview: Font {
        self == .roadSign
            ? Font.custom("Overpass-ExtraBold", size: 22, relativeTo: .title2)
            : Font.system(.title2, design: design, weight: .heavy)
    }

    var nameFont: Font {
        self == .roadSign
            ? Font.custom("Overpass-ExtraBold", size: 17, relativeTo: .headline)
            : Font.system(.headline, design: design, weight: .heavy)
    }

    var sampleFont: Font {
        Font.system(.subheadline, design: design)
    }

    /// For UIKit's navigation-bar titles.
    func uiFont(size: CGFloat, weight: UIFont.Weight, overpass: String) -> UIFont {
        if self == .roadSign, let font = UIFont(name: overpass, size: size) {
            return font
        }
        let system = UIFont.systemFont(ofSize: size, weight: weight)
        let uiDesign: UIFontDescriptor.SystemDesign = switch self {
        case .roadSign, .standard: .default
        case .rounded: .rounded
        case .serif: .serif
        }
        return system.fontDescriptor.withDesign(uiDesign).map { UIFont(descriptor: $0, size: size) } ?? system
    }
}
