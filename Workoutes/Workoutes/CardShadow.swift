import SwiftUI

enum CardRowPosition {
    case single, first, middle, last

    var backgroundShape: UnevenRoundedRectangle {
        let topRadius: CGFloat = self == .single || self == .first ? 26 : 0
        let bottomRadius: CGFloat = self == .single || self == .last ? 26 : 0
        return UnevenRoundedRectangle(
            topLeadingRadius: topRadius,
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            topTrailingRadius: topRadius,
            style: .continuous
        )
    }

    static func row(at index: Int, count: Int) -> Self {
        if count == 1 { return .single }
        if index == 0 { return .first }
        if index == count - 1 { return .last }
        return .middle
    }
}

extension View {
    func subtleCardShadow() -> some View {
        shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    func subtleFormRowShadow(_ position: CardRowPosition = .single) -> some View {
        staggeredTabAppearance()
            .listRowBackground(
                position.backgroundShape
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .subtleCardShadow()
                    .clipShape(FormRowShadowClip(position: position))
                    .staggeredTabAppearance()
            )
    }
}

/// Keep shadows around the section's outside, without casting across adjacent rows.
private struct FormRowShadowClip: Shape {
    let position: CardRowPosition

    func path(in rect: CGRect) -> Path {
        let top: CGFloat = position == .single || position == .first ? 12 : 0
        let bottom: CGFloat = position == .single || position == .last ? 12 : 0
        return Path(CGRect(x: rect.minX - 12, y: rect.minY - top,
                           width: rect.width + 24, height: rect.height + top + bottom))
    }
}
