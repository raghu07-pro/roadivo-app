import SwiftUI

/// "Manage Sources", pushed from Settings. A source opens its channels.
struct SourcesView: View {
    let viewModel: SourcesViewModel
    let revision: Int
    let onAddSource: () -> Void
    let onLibraryChanged: () -> Void
    let onPlay: (MediaItem, [MediaItem]) -> Void
    let onFavoriteChanged: (UUID, Bool) -> Void

    @State private var renaming: SourceSummary?
    @State private var newName = ""
    /// The source waiting for the user to confirm its deletion.
    @State private var deleting: SourceSummary?
    /// The source whose Source Health is open (from the row's menu).
    @State private var checking: SourceSummary?

    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section {
                ForEach(viewModel.sources) { source in
                    NavigationLink(value: source) {
                        SourceRow(source: source, isRefreshing: viewModel.refreshing.contains(source.id))
                    }
                    .accessibilityIdentifier("source.\(source.name)")
                    .swipeActions(edge: .trailing) {
                        // Not role: .destructive, which animates the row
                        // away before the user has confirmed.
                        Button {
                            deleting = source
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                        .accessibilityIdentifier("source.delete")
                    }
                    .contextMenu { menu(for: source) }
                }
            } header: {
                Text("Your Sources")
            } footer: {
                Text("Tap a source to see its channels. Swipe to delete, or touch and hold to refresh or rename.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(.roadCanvas)
        .clearsBottomAccessory()
        .navigationTitle("Manage Sources")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $checking) { source in
            SourceHealthView(viewModel: viewModel.health(for: source), onPlay: onPlay)
        }
        .navigationDestination(for: SourceSummary.self) { source in
            SourceDetailView(
                viewModel: viewModel.detail(for: source),
                revision: revision,
                onPlay: onPlay,
                onFavoriteChanged: onFavoriteChanged,
                onLibraryChanged: onLibraryChanged
            )
        }
        .overlay {
            if viewModel.sources.isEmpty {
                EmptyStateView(
                    title: "No sources added",
                    message: "Start with an M3U subscription, or link a Jellyfin or Emby server.",
                    systemImage: "antenna.radiowaves.left.and.right"
                ) {
                    PrimaryButton(title: "Add a Source", systemImage: "plus", isCompact: true, action: onAddSource)
                }
                .background(.roadCanvas)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onAddSource) { Label("Add Source", systemImage: "plus") }
                    .accessibilityIdentifier("sources.add")
            }
        }
        .alert("Rename Source", isPresented: Binding(get: { renaming != nil }, set: {
            if !$0 {
                renaming = nil
            }
        })) {
            TextField("Name", text: $newName)
            Button("Save") {
                if let renaming, viewModel.rename(renaming.id, to: newName) {
                    onLibraryChanged()
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        // A centred alert, like deleting a video (not a dialog beside the row).
        .alert(
            Text("Delete \(deleting?.name ?? "")?"),
            isPresented: Binding(
                get: { deleting != nil },
                set: {
                    if !$0 {
                        deleting = nil
                    }
                }
            ),
            presenting: deleting
        ) { source in
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete(source.id) {
                        onLibraryChanged()
                    }
                }
            }
            .accessibilityIdentifier("sources.confirmDelete")
            Button("Cancel", role: .cancel) {}
        } message: { source in
            if source.kind == .localVideos {
                Text("All your imported videos are removed from PlayCarTV. The originals stay in Photos or Files.")
            } else {
                Text("""
                Its channels, favorites and watch history are removed from PlayCarTV. To add it again, you'll need \
                its link or login.
                """)
            }
        }
        .alert(
            "Couldn't update the source",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: {
                    if !$0 {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task(id: revision) { viewModel.load() }
    }

    @ViewBuilder
    private func menu(for source: SourceSummary) -> some View {
        if source.kind == .remote || source.kind == .mediaServer {
            Button {
                Task {
                    if await viewModel.refresh(source.id) {
                        onLibraryChanged()
                    }
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        if source.hasHealthReport {
            Button {
                checking = source
            } label: {
                Label("Source Health", systemImage: "stethoscope")
            }
        }
        Button {
            newName = source.name
            renaming = source
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button(role: .destructive) {
            deleting = source
        } label: {
            DestructiveLabel(title: "Delete", systemImage: "trash")
        }
    }
}
