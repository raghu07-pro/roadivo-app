import SwiftUI

struct SourceRow: View {
    let source: SourceSummary
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let server = source.server {
                ServerBadge(kind: server, size: 44)
            } else {
                IconTile(systemImage: source.symbol, style: .soft, size: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name).font(Typography.cardTitle)
                if let server = source.server {
                    // "Jellyfin · demo.jellyfin.org"
                    Text([server.title, source.host].compactMap(\.self).joined(separator: " · "))
                        .font(Typography.caption)
                        .foregroundStyle(.roadMuted)
                }
                // "2 minutes ago" moves on while the screen stays open.
                TimelineView(.everyMinute) { _ in
                    Text(detail).font(Typography.caption).foregroundStyle(.roadMuted)
                }
                health
            }
            Spacer(minLength: 0)
            if isRefreshing {
                ProgressView()
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    /// Source Health at a glance: a failed refresh, else the last stream check.
    @ViewBuilder private var health: some View {
        if source.refreshFailed {
            Label("Last refresh failed", systemImage: "exclamationmark.triangle.fill")
                .font(Typography.caption)
                .foregroundStyle(.red)
        } else if let answered = source.streamsAnswered, let checked = source.streamsChecked, checked > 0 {
            Label(
                String(appLocalized: "\(answered) of \(checked) streams working"),
                systemImage: answered == checked ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
            )
            .font(Typography.caption)
            .foregroundStyle(answered == checked ? Color.secondary : Color.orange)
        }
    }

    /// "2013 channels · Refreshed 5 minutes ago".
    private var detail: String {
        let count = source.kind == .localVideos || source.kind == .mediaServer
            ? String(appLocalized: "\(source.itemCount) items")
            : String(appLocalized: "\(source.itemCount) channels")
        guard let date = source.refreshedAt else { return count }
        let when = date.formatted(.relative(presentation: .named).locale(AppLocale.current))
        let time = source
            .isRefreshable ? String(appLocalized: "Refreshed \(when)") : String(appLocalized: "Added \(when)")
        return "\(count) · \(time)"
    }
}
