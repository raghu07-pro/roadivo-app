import SwiftUI

struct SourceRow: View {
    let source: SourceSummary
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: source.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.roadAccent)
                .frame(width: 44, height: 44)
                .background(.roadSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .accessibilityHidden(true)
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
