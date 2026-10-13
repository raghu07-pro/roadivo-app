import SwiftUI

/// "Manage Sources", pushed from Settings.
struct SourcesView: View {
    let viewModel: SourcesViewModel
    let revision: Int
    let onAddSource: () -> Void
    let onLibraryChanged: () -> Void

    @State private var renaming: SourceSummary?
    @State private var newName = ""

    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section {
                ForEach(viewModel.sources) { source in
                    SourceRow(source: source, isRefreshing: viewModel.refreshing.contains(source.id))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                if viewModel.delete(source.id) {
                                    onLibraryChanged()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu { menu(for: source) }
                }
            } header: {
                Text("Your Sources")
            } footer: {
                Text("Swipe to delete. Touch and hold to refresh or rename.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(.roadCanvas)
        .navigationTitle("Manage Sources")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.sources.isEmpty {
                ContentUnavailableView {
                    Label("No sources added", systemImage: "tray")
                } description: {
                    Text("Start with an M3U subscription, or link a Jellyfin or Emby server.")
                } actions: {
                    PrimaryButton(title: "Add a Source", systemImage: "plus", isCompact: true, action: onAddSource)
                }
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
        Button {
            newName = source.name
            renaming = source
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button(role: .destructive) {
            if viewModel.delete(source.id) {
                onLibraryChanged()
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
