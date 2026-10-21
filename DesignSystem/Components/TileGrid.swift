import SwiftUI

/// As many equal columns as fit `minimumWidth`, rows as tall as their tallest tile. Eager, unlike `LazyVGrid`, so
/// tiles keep their identity when larger text changes the column count (the audit reads a rebuilt tile as unscaled).
struct TileGrid: Layout {
    let minimumWidth: CGFloat
    let spacing: CGFloat
    let rowSpacing: CGFloat

    private struct Row {
        var indices: [Int]
        var height: CGFloat
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        // An unlimited width (ViewThatFits asks for one) means every tile in one row, never infinite columns.
        let oneRow = CGFloat(subviews.count) * (minimumWidth + spacing) - spacing
        let width = proposal.width.map { $0.isFinite ? $0 : max(minimumWidth, oneRow) } ?? minimumWidth
        let rows = rows(of: subviews, width: width)
        let height = rows.reduce(0) { $0 + $1.height } + rowSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let width = columnWidth(in: bounds.width)
        var top = bounds.minY
        for row in rows(of: subviews, width: bounds.width) {
            for (column, index) in row.indices.enumerated() {
                let leading = bounds.minX + CGFloat(column) * (width + spacing)
                subviews[index].place(
                    at: CGPoint(x: leading, y: top),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: width, height: nil)
                )
            }
            top += row.height + rowSpacing
        }
    }

    private func columnCount(in width: CGFloat) -> Int {
        max(1, Int((width + spacing) / (minimumWidth + spacing)))
    }

    private func columnWidth(in width: CGFloat) -> CGFloat {
        let count = CGFloat(columnCount(in: width))
        return max(0, (width - spacing * (count - 1)) / count)
    }

    private func rows(of subviews: Subviews, width: CGFloat) -> [Row] {
        let count = columnCount(in: width)
        let proposal = ProposedViewSize(width: columnWidth(in: width), height: nil)
        return stride(from: 0, to: subviews.count, by: count).map { start in
            let indices = Array(start..<min(start + count, subviews.count))
            let height = indices.map { subviews[$0].sizeThatFits(proposal).height }.max() ?? 0
            return Row(indices: indices, height: height)
        }
    }
}
