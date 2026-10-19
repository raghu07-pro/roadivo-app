import Network
import OSLog
import ReplayKit
import SwiftUI

/// Apple's Screen Broadcast sheet, opened from Roadivo's own button. Apple offers no call to open it, so the
/// system picker stays out of sight and its button is tapped for it.
@MainActor
final class BroadcastPicker {
    private static let logger = Logger(subsystem: "com.roadivo", category: "Broadcast")

    /// Built on first use, so the throwaway copies `@State` makes on every parent render never build one.
    private(set) lazy var view: RPSystemBroadcastPickerView = {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        // Roadivo's own extension is preselected, so the sheet lists it ready to start.
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

/// Asks for local network access, without which the car screen's browser can't reach the iPhone, and notices a
/// refusal. A short search for Roadivo's own service is what makes iOS ask.
@MainActor
@Observable
final class LocalNetworkAccess {
    private(set) var isDenied = false
    @ObservationIgnored private var browser: NWBrowser?

    func request() {
        guard browser == nil else { return }
        let search = NWBrowser(for: .bonjour(type: "_roadivo._tcp", domain: nil), using: .tcp)
        search.stateUpdateHandler = { [weak self] state in
            guard let denied = state.localNetworkDenial else { return }
            MainActor.assumeIsolated { // Delivered on .main, the queue the search starts on.
                guard let self else { return }
                self.isDenied = denied
            }
        }
        search.start(queue: .main)
        browser = search
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5)) // Long enough for iOS to ask; cancelling just stops sooner.
            search.cancel()
            self?.browser = nil
        }
    }
}

private extension NWBrowser.State {
    /// `true` when iOS blocks the search because Local Network is off for Roadivo, `false` once it runs.
    var localNetworkDenial: Bool? {
        switch self {
        case .ready:
            return false
        case let .waiting(error) where error == .dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied)):
            return true
        default:
            return nil
        }
    }
}
