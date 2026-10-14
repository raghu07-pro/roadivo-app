import AVKit
import SwiftUI

/// The system AirPlay picker: sends video to an AirPlay receiver such as a
/// car-display adapter or a TV.
struct RoutePickerButton: UIViewRepresentable {
    var tint: UIColor = .white

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = tint
        picker.activeTintColor = AppTheme.shared.accent.uiAccent
        picker.accessibilityLabel = String(appLocalized: "AirPlay")
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {
        picker.tintColor = tint
        picker.activeTintColor = AppTheme.shared.accent.uiAccent
    }
}
