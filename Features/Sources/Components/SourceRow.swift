import SwiftUI

struct SourceRow: View {
    let source: SourceSummary
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            IconTile(systemImage: source.symbol, style: .soft, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name).font(Typography.cardTitle)
                Text(detail).font(Typography.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isRefreshing {
                ProgressView()
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let count = String(appLocalized: "\(source.itemCount) items")
        guard let host = source.host else { return count }
        return "\(count) · \(host)"
    }
}
