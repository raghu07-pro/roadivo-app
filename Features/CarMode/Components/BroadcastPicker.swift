import OSLog
import ReplayKit
import SwiftUI

/// Apple's Screen Broadcast sheet, opened from PlayCarTV's own button. Apple offers no call to open it, so the
/// system picker stays out of sight and its button is tapped for it.
@MainActor
final class BroadcastPicker {
    private static let logger = Logger(subsystem: "com.playcartv", category: "Broadcast")

    /// Built on first use, so the throwaway copies `@State` makes on every parent render never build one.
    private(set) lazy var view: RPSystemBroadcastPickerView = {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        // PlayCarTV's own extension is preselected, so the sheet lists it ready to start.
        picker.preferredExtension = Bundle.main.bundleIdentifier.map { $0 + ".broadcast" }
        picker.showsMicrophoneButton = false
        return picker
    }()

    func show() {
        guard let button = view.subviews.lazy.compactMap({ $0 as? UIButton }).first else {
            Self.logger.error("Screen Broadcast's button wasn't found, so its sheet can't open")
            return
        }
        button.sendActions(for: .touchUpInside)
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

/// Whether PlayCarTV's Screen Broadcast is running, so Cast to Screen's one button starts or ends it.
@MainActor
@Observable
final class BroadcastStatus {
    private(set) var isBroadcasting = false
    /// UI tests stand in for a running broadcast, which needs a real iPhone.
    private let isBroadcastingForTests: Bool = {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            return arguments.contains("-ui-testing") && arguments.contains("-broadcasting")
        #else
            return false
        #endif
    }()

    /// Looks once a second while Cast to Screen is open; the page's task ends it.
    func watch() async {
        while !Task.isCancelled {
            let isRunning = isBroadcastingForTests ? true : await BroadcastProbe.isRunning()
            if isRunning != isBroadcasting {
                isBroadcasting = isRunning
            }
            try? await Task.sleep(for: .seconds(1)) // Throws only when cancelled, and the loop then ends.
        }
    }
}
