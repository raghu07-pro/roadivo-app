import Network
import ReplayKit
import SwiftUI

/// Apple's Screen Broadcast sheet, opened from Roadivo's own button. Apple offers no call to open it, so the
/// system picker stays out of sight and its button is tapped for it.
@MainActor
final class BroadcastPicker {
    let view: RPSystemBroadcastPickerView = {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        // Roadivo's own extension is preselected, so the sheet lists it ready to start.
        picker.preferredExtension = Bundle.main.bundleIdentifier.map { $0 + ".broadcast" }
        picker.showsMicrophoneButton = false
        return picker
    }()

    func show() {
        (view.subviews.first { $0 is UIButton } as? UIButton)?.sendActions(for: .touchUpInside)
    }
}

/// Keeps the system picker in the window, where its sheet can present from, without showing it.
struct BroadcastPickerHost: UIViewRepresentable {
    let picker: BroadcastPicker

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        picker.view
    }

    func updateUIView(_ view: RPSystemBroadcastPickerView, context: Context) {}
}

/// Asks for local network access before a broadcast starts: without it, the car screen's browser can't reach the
/// iPhone. A short search for Roadivo's own service is what makes iOS ask.
@MainActor
enum LocalNetworkAccess {
    private static var browser: NWBrowser?

    static func request() {
        guard browser == nil else { return }
        let search = NWBrowser(for: .bonjour(type: "_roadivo._tcp", domain: nil), using: .tcp)
        search.start(queue: .main) // Network delivers its events on a queue.
        browser = search
        Task {
            try? await Task.sleep(for: .seconds(5)) // Long enough for iOS to ask; cancelling just stops sooner.
            search.cancel()
            browser = nil
        }
    }
}
