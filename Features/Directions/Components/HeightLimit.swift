import SwiftUI

/// Offers its content at most `limit` points of height and takes only the height the content uses. Unlike
/// `.frame(maxHeight:)`, which grows to the limit and centres a short card in the empty space.
struct HeightLimit: Layout {
    let limit: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let height = min(proposal.height ?? limit, limit)
        return content.sizeThatFits(ProposedViewSize(width: proposal.width, height: height))
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        subviews.first?.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )
    }
}
