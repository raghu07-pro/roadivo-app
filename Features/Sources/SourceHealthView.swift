import SwiftUI

/// Source Health, from Manage Sources: whether the source is working, its last refresh, the entries
/// it couldn't read, and a check of its streams (its server or files, for the other kinds).
struct SourceHealthView: View {
    @State var viewModel: SourceHealthViewModel
    let onPlay: (MediaItem, [MediaItem]) -> Void

    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section {
                HealthStatusHeader(status: viewModel.status, summary: summary)
            }
            switch viewModel.kind {
            case .remote, .file:
                playlistSection
                streamsSection
                problemsSection
            case .mediaServer:
                playlistSection
                serverSection
            case .localVideos:
                filesSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(.roadCanvas)
        .clearsBottomAccessory()
        .navigationTitle("Source Health")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.load()
            if viewModel.kind == .mediaServer, viewModel.serverOutcome == nil {
                await viewModel.checkServer()
            }
        }
        .onDisappear { viewModel.stop() }
        .alert(
            "Couldn't check the source",
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
    }

    // MARK: Sections

    private static let unsupportedLinkNote: LocalizedStringKey =
        "PlayCarTV plays http, https, rtmp and rtsp links; entries with udp or file links are skipped."

    @ViewBuilder private var playlistSection: some View {
        if let health = viewModel.health {
            Section {
                StatRow(
                    title: viewModel.kind == .mediaServer ? "Items" : "Channels",
                    value: health.channelCount.formatted()
                )
                StatRow(
                    title: viewModel.kind == .file ? "Added" : "Last refreshed",
                    value: health.refreshedAt.map(relative) ?? String(appLocalized: "Never")
                )
                if let error = health.lastRefreshError {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Label("Last refresh failed", systemImage: "exclamationmark.triangle.fill")
                            .font(Typography.cardTitle)
                            .foregroundStyle(.red)
                        Text(error)
                            .font(Typography.secondary)
                        if let attempt = health.lastRefreshAttemptAt {
                            Text(relative(attempt))
                                .font(Typography.caption)
                                .foregroundStyle(.roadMuted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("health.refreshError")
                }
                if let issues = health.issues {
                    StatRow(title: "Entries without a link", value: issues.withoutLink.counted)
                    StatRow(title: "Links PlayCarTV can't play", value: issues.unsupportedLink.counted)
                        .accessibilityIdentifier("health.unsupported")
                }
            } header: {
                Text("Playlist")
            } footer: {
                if (health.issues?.unsupportedLink ?? 0) > 0 {
                    Text(Self.unsupportedLinkNote)
                }
            }
        }
    }

    private var streamsSection: some View {
        Section {
            if let report = viewModel.report {
                StatRow(title: "Working", value: report.working.counted)
                    .accessibilityIdentifier("health.working")
                StatRow(title: "Slow (over 3 seconds)", value: report.slow.counted)
                StatRow(title: "Not working", value: report.failed.counted)
                    .accessibilityIdentifier("health.failed")
                if report.unchecked > 0 {
                    StatRow(title: "Not checked (rtmp, rtsp)", value: report.unchecked.counted)
                }
                if viewModel.isChecking {
                    ProgressView(value: Double(report.checked + report.unchecked), total: Double(max(
                        report.total,
                        1
                    ))) {
                        Text("Checking \(report.checked + report.unchecked) of \(report.total)…")
                            .font(Typography.secondary)
                    }
                    .accessibilityIdentifier("health.progress")
                } else {
                    Text(lastCheckLine(report))
                        .font(Typography.caption)
                        .foregroundStyle(.roadMuted)
                }
            } else {
                Text("Check each stream to see which ones answer, which are slow and which have stopped working.")
                    .font(Typography.secondary)
                    .foregroundStyle(.roadMuted)
            }
            if viewModel.isChecking {
                Button("Stop", role: .destructive, action: viewModel.stop)
                    .accessibilityIdentifier("health.stop")
            } else {
                Button(viewModel.report == nil ? "Check Streams" : "Check Again", action: viewModel.checkStreams)
                    .font(Typography.cardTitle)
                    .accessibilityIdentifier("health.check")
            }
        } header: {
            Text("Streams")
        } footer: {
            Text("""
            PlayCarTV checks two streams at a time, so your provider's connection limit isn't hit. Live \
            streams come and go, so check again later if many fail.
            """)
        }
    }

    @ViewBuilder private var problemsSection: some View {
        if let report = viewModel.report, !report.problems.isEmpty {
            Section {
                ForEach(report.problems) { problem in
                    Button {
                        if let item = viewModel.item(for: problem) {
                            onPlay(item, [item])
                        }
                    } label: {
                        ProblemRow(problem: problem)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Plays this channel"))
                }
            } header: {
                Text("Streams with problems")
            } footer: {
                if report.problems.count < report.failed + report.slow {
                    Text("Showing the first \(report.problems.count) of \(report.failed + report.slow).")
                }
            }
        }
    }

    private var serverSection: some View {
        Section {
            if viewModel.isCheckingServer {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("Checking the server…").font(Typography.secondary)
                }
            } else if let outcome = viewModel.serverOutcome {
                Text(Self.describe(outcome))
                    .font(Typography.secondary)
                    .accessibilityIdentifier("health.server")
            }
            Button("Check Again") { Task { await viewModel.checkServer() } }
                .font(Typography.cardTitle)
                .disabled(viewModel.isCheckingServer)
        } header: {
            Text("Server")
        } footer: {
            Text("PlayCarTV checks the server rather than each video, so it doesn't start a transcode for every item.")
        }
    }

    private var filesSection: some View {
        Section {
            if viewModel.missingVideos.isEmpty {
                Text("Every video is on this iPhone.").font(Typography.secondary)
            } else {
                ForEach(viewModel.missingVideos) { item in
                    Label(item.title, systemImage: "exclamationmark.triangle.fill")
                        .font(Typography.secondary)
                }
            }
        } header: {
            Text("Files")
        } footer: {
            if !viewModel.missingVideos.isEmpty {
                Text("These videos' files are gone. Delete them and import them again from Photos or Files.")
            }
        }
    }

    // MARK: Text

    /// The line under the status: the most useful thing to know first.
    private var summary: String {
        let health = viewModel.health
        switch viewModel.status {
        case .unchecked:
            return viewModel.kind == .mediaServer
                ? String(appLocalized: "Checking the server…")
                : String(appLocalized: "Check the streams to see which ones work.")
        case .healthy:
            if viewModel.kind == .localVideos {
                return String(appLocalized: "Every video is on this iPhone.")
            }
            if let report = viewModel.report, report.checked > 0 {
                return String(appLocalized: "All \(report.checked) checked streams answered.")
            }
            return viewModel.serverOutcome.map(Self.describe) ?? ""
        case .attention, .failing:
            if case let .failed(problem) = viewModel.serverOutcome {
                return problem.description
            }
            if !viewModel.missingVideos.isEmpty {
                return String(appLocalized: "\(viewModel.missingVideos.count) videos are missing from this iPhone.")
            }
            if let report = viewModel.report, report.failed > 0 {
                return String(appLocalized: "\(report.failed) of \(report.checked) checked streams didn't answer.")
            }
            if health?.refreshFailed == true {
                return String(appLocalized: "The last refresh failed.")
            }
            if let report = viewModel.report, report.slow > 0 {
                return String(appLocalized: "\(report.slow) streams were slow to answer.")
            }
            return String(appLocalized: "\(health?.issues?.total ?? 0) entries in the playlist couldn't be used.")
        }
    }

    private func lastCheckLine(_ report: StreamCheckReport) -> String {
        let when = relative(report.checkedAt)
        return report.isComplete
            ? String(appLocalized: "Checked \(when)")
            : String(appLocalized: "Stopped after \(report.checked + report.unchecked) of \(report.total), \(when)")
    }

    private func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named).locale(AppLocale.current))
    }

    static func describe(_ outcome: StreamOutcome) -> String {
        switch outcome {
        case let .working(milliseconds): String(appLocalized: "Answered in \(milliseconds) ms")
        case let .slow(milliseconds): String(appLocalized: "Slow: answered in \(milliseconds) ms")
        case let .failed(problem): problem.description
        case .unchecked: String(appLocalized: "Not checked")
        }
    }
}

/// The status at the top: one symbol, one word, one line.
private struct HealthStatusHeader: View {
    let status: SourceHealthViewModel.Status
    let summary: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.sectionTitle)
                Text(summary)
                    .font(Typography.secondary)
                    .foregroundStyle(.roadMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("health.status")
    }

    private var title: LocalizedStringKey {
        switch status {
        case .unchecked: "Not checked yet"
        case .healthy: "Looks healthy"
        case .attention: "Needs attention"
        case .failing: "Mostly not working"
        }
    }

    private var symbol: String {
        switch status {
        case .unchecked: "stethoscope"
        case .healthy: "checkmark.seal.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .failing: "xmark.octagon.fill"
        }
    }

    /// No green (the brand): healthy is the accent, trouble is orange, failing is red.
    private var tint: Color {
        switch status {
        case .unchecked: .secondary
        case .healthy: .roadAccent
        case .attention: .orange
        case .failing: .red
        }
    }
}

/// One stream with a problem: its name, group and what went wrong.
private struct ProblemRow: View {
    let problem: StreamCheckReport.Problem

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: problem.isSlow ? "tortoise.fill" : "xmark.circle.fill")
                .foregroundStyle(problem.isSlow ? Color.orange : Color.red)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(problem.title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                Text("\(problem.group) · \(SourceHealthView.describe(problem.outcome))")
                    .font(Typography.caption)
                    .foregroundStyle(.roadMuted)
            }
            Spacer(minLength: 0)
            Image(systemName: "play.circle")
                .foregroundStyle(.roadAccent)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private extension Int {
    /// "1,240" in the app's language.
    var counted: String {
        formatted(.number.locale(AppLocale.current))
    }
}

/// A label and its value: side by side, or stacked at the largest text sizes so neither is cut.
private struct StatRow: View {
    let title: LocalizedStringKey
    let value: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                    Text(value).foregroundStyle(.roadMuted)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(title)
                    Spacer(minLength: Spacing.sm)
                    Text(value)
                        .foregroundStyle(.roadMuted)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .font(Typography.body)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Largest text") {
    List {
        StatRow(title: "Links PlayCarTV can't play", value: "12")
        StatRow(title: "Last refreshed", value: "5 minutes ago")
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Status, light and dark") {
    List {
        HealthStatusHeader(status: .healthy, summary: "All 1,240 checked streams answered.")
        HealthStatusHeader(status: .attention, summary: "6 of 13 checked streams didn't answer.")
        HealthStatusHeader(status: .failing, summary: "Server not found")
        HealthStatusHeader(status: .unchecked, summary: "Check the streams to see which ones work.")
    }
    .preferredColorScheme(.dark)
}
