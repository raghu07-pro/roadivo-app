import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// "Cast from an app", in CarTV's place (owner, 2026-10-19): another app's video goes to the car with that
/// app's own AirPlay button, and the user's own videos play in Roadivo, ready for AirPlay or Car Mode.
/// CarTV listens for DLNA casts instead, which needs Apple's multicast entitlement (DECISIONS 120).
struct CastFromAppView: View {
    let connection: CarConnection
    /// Adds the picked videos to On this iPhone and plays the first; a message when that couldn't happen.
    let onImport: (_ urls: [URL], _ skipped: Int, _ isTemporary: Bool) async -> String?

    @State private var isPickingFiles = false
    @State private var isPickingPhotos = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var problem: String?

    private static let videoTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
    /// Casting from other apps, behind the ? in the navigation bar (DECISIONS 128).
    private static let steps: [LocalizedStringResource] = [
        "Connect your iPhone to the car's AirPlay display or wireless adapter.",
        "Play a video in any app that has an AirPlay button.",
        "Tap AirPlay and choose the car's display. Some apps limit quality or block certain videos."
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                carScreen
                SectionHeader("Your Videos")
                VStack(spacing: 0) {
                    row("Choose Files", symbol: "folder", identifier: "castApp.files") { isPickingFiles = true }
                    Divider()
                        .padding(.leading, 56)
                    row("From Photos", symbol: "photo.on.rectangle", identifier: "castApp.photos") {
                        isPickingPhotos = true
                    }
                }
                .padding(.horizontal, Spacing.md)
                .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                Text("Your videos are added to On this iPhone in Favorites, then play in Roadivo.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(.roadCanvas)
        .clearsBottomAccessory()
        .navigationTitle("Cast from an app")
        .navigationBarTitleDisplayMode(.inline)
        .stepsHelp(identifier: "castApp", steps: Self.steps)
        .overlay {
            if isImporting {
                LoadingView(message: "Importing…")
                    .background(.roadCanvas.opacity(0.9))
            }
        }
        .disabled(isImporting)
        .fileImporter(
            isPresented: $isPickingFiles,
            allowedContentTypes: Self.videoTypes,
            allowsMultipleSelection: true
        ) { result in
            guard case let .success(urls) = result else { return }
            importing { await onImport(urls, 0, false) }
        }
        .photosPicker(isPresented: $isPickingPhotos, selection: $photoSelection, matching: .videos)
        .onChange(of: photoSelection) { _, picked in importPhotos(picked) }
        .alert(
            "Couldn't import",
            isPresented: Binding(get: { problem != nil }, set: {
                if !$0 {
                    problem = nil
                }
            })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(problem ?? "")
        }
        .accessibilityIdentifier("castApp.screen")
    }

    /// The car's screen, as in CarTV: named once AirPlay reaches it.
    private var carScreen: some View {
        VStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(.roadSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 6)
                }
                .overlay {
                    Text(connection.airPlayDestination ?? String(appLocalized: "Car screen"))
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(Spacing.md)
                }
                .aspectRatio(16 / 10, contentMode: .fit)
                .frame(maxWidth: 260)
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 90, height: 6)
            Text(connection.airPlayDestination == nil ? "Waiting for an AirPlay screen…" : "Connected with AirPlay")
                .font(Typography.secondary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("castApp.status")
    }

    private func row(
        _ title: LocalizedStringKey,
        symbol: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                IconTile(systemImage: symbol, style: .soft, size: 36)
                Text(title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier(identifier)
    }

    private func importing(_ work: @escaping () async -> String?) {
        isImporting = true
        Task {
            problem = await work()
            isImporting = false
        }
    }

    /// Photos hands over copies in a temporary folder, removed once imported.
    private func importPhotos(_ picked: [PhotosPickerItem]) {
        guard !picked.isEmpty else { return }
        importing {
            var urls: [URL] = []
            for item in picked {
                // A pick that won't export counts as skipped, and the import reports it.
                if let video = try? await item.loadTransferable(type: PickedVideo.self) {
                    urls.append(video.url)
                }
            }
            photoSelection = []
            return await onImport(urls, picked.count - urls.count, true)
        }
    }
}
