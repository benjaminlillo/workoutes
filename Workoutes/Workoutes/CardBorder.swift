import SwiftUI

enum CardRowPosition {
    case single, first, middle, last

    static func row(at index: Int, count: Int) -> Self {
        if count == 1 { return .single }
        if index == 0 { return .first }
        if index == count - 1 { return .last }
        return .middle
    }
}

struct SubtleCardBorder<S: InsettableShape>: View {
    let shape: S
    @AppStorage("appAccentColor") private var accentColorRawValue: String = ThemeColor.primary.rawValue

    private var accentColor: Color {
        ThemeColor(rawValue: accentColorRawValue)?.color ?? .mint
    }

    var body: some View {
        shape.strokeBorder(
            LinearGradient(
                colors: [accentColor.opacity(0.24), accentColor.opacity(0.08), accentColor.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 1
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func subtleCardBorder(cornerRadius: CGFloat = 18) -> some View {
        overlay {
            SubtleCardBorder(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    func subtleFormRowBorder(_ position: CardRowPosition = .single) -> some View {
        listRowBackground(
            Color(uiColor: .secondarySystemGroupedBackground)
                .overlay { SubtleCardBorder(shape: FormRowOutline(position: position)) }
        )
    }
}

/// Outlines the whole section, leaving its internal row separators to the system.
private struct FormRowOutline: InsettableShape {
    let position: CardRowPosition
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> Self {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        // Internal row edges meet directly so the section outline stays continuous.
        let topInset = position == .single || position == .first ? insetAmount : 0
        let bottomInset = position == .single || position == .last ? insetAmount : 0
        let bounds = CGRect(
            x: rect.minX + insetAmount,
            y: rect.minY + topInset,
            width: rect.width - insetAmount * 2,
            height: rect.height - topInset - bottomInset
        )
        let topRadius: CGFloat = position == .single || position == .first ? 26 : 0
        let bottomRadius: CGFloat = position == .single || position == .last ? 26 : 0
        let outline = UnevenRoundedRectangle(
            topLeadingRadius: topRadius,
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            topTrailingRadius: topRadius,
            style: .continuous
        ).path(in: bounds)
        if position == .single { return outline }

        var result = Path()
        var cursor = CGPoint.zero
        var start = CGPoint.zero
        func addEdge(to point: CGPoint) {
            let isTop = abs(cursor.y - bounds.minY) < 0.01 && abs(point.y - bounds.minY) < 0.01
            let isBottom = abs(cursor.y - bounds.maxY) < 0.01 && abs(point.y - bounds.maxY) < 0.01
            if (isTop && position != .first) || (isBottom && position != .last) {
                result.move(to: point)
            } else {
                result.addLine(to: point)
            }
            cursor = point
        }
        outline.cgPath.applyWithBlock { pointer in
            let element = pointer.pointee
            switch element.type {
            case .moveToPoint:
                start = element.points[0]
                cursor = start
                result.move(to: start)
            case .addLineToPoint:
                addEdge(to: element.points[0])
            case .addQuadCurveToPoint:
                result.addQuadCurve(to: element.points[1], control: element.points[0])
                cursor = element.points[1]
            case .addCurveToPoint:
                result.addCurve(to: element.points[2], control1: element.points[0], control2: element.points[1])
                cursor = element.points[2]
            case .closeSubpath:
                addEdge(to: start)
            @unknown default:
                break
            }
        }
        return result
    }
}
