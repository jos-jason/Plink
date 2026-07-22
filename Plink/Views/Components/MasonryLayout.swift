import SwiftUI

struct MasonryLayout: Layout {
    var columns: Int
    var spacing: CGFloat

    init(columns: Int = 2, spacing: CGFloat = AppConstants.cardSpacing) {
        self.columns = max(1, columns)
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let containerWidth = proposal.width ?? 300
        let positions = computePositions(
            subviews: subviews,
            containerWidth: containerWidth
        )
        let maxY = positions.map(\.maxY).max() ?? 0
        return CGSize(width: containerWidth, height: maxY)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let positions = computePositions(
            subviews: subviews,
            containerWidth: bounds.width
        )

        for (index, subview) in subviews.enumerated() {
            guard index < positions.count else { break }
            let rect = positions[index]
            subview.place(
                at: CGPoint(
                    x: bounds.minX + rect.origin.x,
                    y: bounds.minY + rect.origin.y
                ),
                proposal: ProposedViewSize(
                    width: rect.width,
                    height: rect.height
                )
            )
        }
    }

    private func computePositions(
        subviews: Subviews,
        containerWidth: CGFloat
    ) -> [CGRect] {
        let columnWidth = (containerWidth - spacing * CGFloat(columns - 1))
            / CGFloat(columns)
        var columnHeights = Array(repeating: CGFloat(0), count: columns)
        var positions: [CGRect] = []

        for subview in subviews {
            // Place in the shortest column
            let shortestColumn = columnHeights.enumerated()
                .min(by: { $0.element < $1.element })!.offset

            let x = CGFloat(shortestColumn) * (columnWidth + spacing)
            let y = columnHeights[shortestColumn]

            let size = subview.sizeThatFits(
                ProposedViewSize(width: columnWidth, height: nil)
            )

            positions.append(CGRect(
                x: x,
                y: y,
                width: columnWidth,
                height: size.height
            ))

            columnHeights[shortestColumn] += size.height + spacing
        }

        return positions
    }
}
