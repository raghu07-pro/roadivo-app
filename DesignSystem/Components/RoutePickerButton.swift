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
        picker.activeTintColor = UIColor(named: "AccentColor")
        picker.accessibilityLabel = String(appLocalized: "AirPlay")
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {
        picker.tintColor = tint
    }
}
