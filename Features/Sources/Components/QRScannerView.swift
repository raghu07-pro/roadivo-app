import PhotosUI
import SwiftUI
import VisionKit

/// Live camera QR scanner. Returns the first code's text (a playlist link or
/// M3U content). Only offered where `isAvailable` is true (not the simulator).
struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

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
        // Fails only without camera permission; the sheet's close button stays usable.
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Void
        private var delivered = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
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
    @State private var photo: PhotosPickerItem?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if QRScannerView.isAvailable {
                QRScannerView { text in
                    onResult(text)
                    dismiss()
                }
                .ignoresSafeArea()
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                    .frame(width: 240, height: 240)
                    .accessibilityHidden(true)
            } else {
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
                Text("Point at a QR code, or pick a photo from the top right.")
                    .font(Typography.secondary)
                    .multilineTextAlignment(.center)
                    .padding(Spacing.md)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
            .padding(Spacing.md)
            .foregroundStyle(.white)
        }
        .environment(\.colorScheme, .dark)
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                onResult(data.flatMap(QRCodeReader.decode(imageData:)))
                dismiss()
            }
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
