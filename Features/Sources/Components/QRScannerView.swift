import AVFoundation
import OSLog
import PhotosUI
import SwiftUI
import VisionKit

private let scannerLogger = Logger(subsystem: "com.playcartv", category: "Scanner")

/// Live camera QR scanner. Returns the first code's text (a playlist link or
/// M3U content). Only offered where `isAvailable` is true (not the simulator).
struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    /// The camera stopped being usable, as when access is denied at the prompt.
    var onUnavailable: () -> Void = {}

    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        do {
            try scanner.startScanning()
        } catch {
            scannerLogger.error("Scanning didn't start: \(error.localizedDescription, privacy: .public)")
            context.coordinator.reportUnavailable()
        }
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onUnavailable: onUnavailable)
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Void
        private let onUnavailable: () -> Void
        private var delivered = false

        init(onScan: @escaping (String) -> Void, onUnavailable: @escaping () -> Void) {
            self.onScan = onScan
            self.onUnavailable = onUnavailable
        }

        /// Deferred a turn: this can come while SwiftUI is still building the view.
        func reportUnavailable() {
            Task { @MainActor [weak self] in
                self?.onUnavailable()
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            scannerLogger.error("Scanner became unavailable: \(error.localizedDescription, privacy: .public)")
            reportUnavailable()
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !delivered else { return }
            for item in addedItems {
                if case let .barcode(code) = item, let text = code.payloadStringValue {
                    delivered = true
                    onScan(text)
                    return
                }
            }
        }
    }
}

/// Full-screen scanner: the live camera where available, plus "pick a photo" (top right) to read
/// a QR code from a screenshot; without a camera, only the photo option.
struct QRScannerSheet: View {
    let onResult: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var photo: PhotosPickerItem?
    @State private var camera = CameraState.current

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch camera {
            case .available:
                QRScannerView(
                    onScan: { text in
                        onResult(text)
                        dismiss()
                    },
                    onUnavailable: { camera = CameraState.current == .denied ? .denied : .unavailable }
                )
                .ignoresSafeArea()
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                    .frame(width: 240, height: 240)
                    .accessibilityHidden(true)
            case .denied:
                ContentUnavailableView {
                    Label("Camera access is off", systemImage: "camera")
                } description: {
                    Text("To scan a QR code, allow camera access in Settings. Or pick a photo or screenshot of it.")
                } actions: {
                    PrimaryButton(title: "Allow Camera in Settings", systemImage: "gear", isCompact: true) {
                        if let settings = URL(string: UIApplication.openSettingsURLString) {
                            openURL(settings)
                        }
                    }
                    .accessibilityIdentifier("scanner.settings")
                }
                .foregroundStyle(.white)
            case .unavailable:
                ContentUnavailableView(
                    "Camera scanning isn't available",
                    systemImage: "camera",
                    description: Text("Pick a photo or screenshot of the QR code instead.")
                )
                .foregroundStyle(.white)
            }
            VStack {
                HStack {
                    circleButton(symbol: "xmark", label: "Close scanner") { dismiss() }
                    Spacer()
                    PhotosPicker(selection: $photo, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3.weight(.bold))
                            .frame(width: 52, height: 52)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel(Text("Pick a photo"))
                    .accessibilityIdentifier("scanner.photo")
                }
                Spacer()
                if camera == .available {
                    Text("Point at a QR code, or pick a photo from the top right.")
                        .font(Typography.secondary)
                        .multilineTextAlignment(.center)
                        .padding(Spacing.md)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        )
                }
            }
            .padding(Spacing.md)
            .foregroundStyle(.white)
        }
        .environment(\.colorScheme, .dark)
        // Back from Settings with access allowed: start the camera.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, camera != .available {
                camera = .current
            }
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                onResult(data.flatMap(QRCodeReader.decode(imageData:)))
                dismiss()
            }
        }
    }

    private enum CameraState {
        case available
        case denied
        case unavailable

        @MainActor static var current: CameraState {
            // Settings can only help where live scanning exists (not the simulator).
            if DataScannerViewController.isSupported, AVCaptureDevice.authorizationStatus(for: .video) == .denied {
                return .denied
            }
            return QRScannerView.isAvailable ? .available : .unavailable
        }
    }

    private func circleButton(symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier("scanner.close")
    }
}
