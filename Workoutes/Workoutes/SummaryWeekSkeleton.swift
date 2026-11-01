import SwiftUI

enum SummaryCardKind: Hashable {
    case muscle, week, tags, totals
}

struct SummaryCardHeightsKey: PreferenceKey {
    static let defaultValue: [SummaryCardKind: CGFloat] = [:]

    static func reduce(value: inout [SummaryCardKind: CGFloat], nextValue: () -> [SummaryCardKind: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Simple shapes and bundled body silhouettes; no queries, mask composition or chart calculations.
struct SummaryWeekSkeleton: View {
    let week: Date
    let today: Date
    var heights: [SummaryCardKind: CGFloat] = [:]

    var body: some View {
        VStack(spacing: 16) {
            ForEach([SummaryCardKind.muscle, .week, .tags, .totals], id: \.self) { kind in
                SummaryCardSkeleton(kind: kind, week: week, today: today)
                    .frame(height: heights[kind])
            }
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
        .accessibilityIdentifier("summaryWeekSkeleton")
        .allowsHitTesting(false)
    }
}

struct SummaryCardSkeleton: View {
    let kind: SummaryCardKind
    let week: Date
    let today: Date
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var titleHeight: CGFloat = 24
    @ScaledMetric(relativeTo: .caption) private var captionHeight: CGFloat = 14
    @ScaledMetric(relativeTo: .caption) private var chartHeight: CGFloat = 190

    var body: some View {
        SummarySkeletonCardLayout(kind: kind, defaultHeight: idealHeight,
                                  accessibilitySize: dynamicTypeSize.isAccessibilitySize) {
            GeometryReader { geometry in
                if kind == .totals {
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                    layout {
                        SummaryStatisticCard(title: String(localized: "Completed Exercises"), value: nil, symbol: "checkmark.circle")
                        SummaryStatisticCard(title: String(localized: "Active Days"), value: nil, symbol: "calendar")
                    }
                } else if kind == .tags {
                    tagDistribution(size: geometry.size)
                        .statisticCardBackground()
                } else {
                    VStack(alignment: .leading, spacing: kind == .week ? 20 : 16) {
                        Text(LocalizedStringKey(kind == .muscle ? "Muscle Activity" : "Week Summary"))
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        switch kind {
                        case .muscle:
                            VStack(spacing: 6) {
                                HStack {
                                    Text("Front").frame(maxWidth: .infinity)
                                    Text("Back").frame(maxWidth: .infinity)
                                }
                                .font(.caption).foregroundStyle(.secondary)
                                GeometryReader { diagram in
                                    let height = min(320, diagram.size.width * 0.86, diagram.size.height)
                                    ZStack {
                                        ForEach(MuscleBodySide.allCases, id: \.self) { side in
                                            // Already assembled offline from the same tag-icon paths.
                                            Image(side.asset("base"))
                                                .resizable()
                                                .foregroundStyle(placeholder)
                                                .frame(width: height / 2, height: height)
                                                .position(x: diagram.size.width * (side == .front ? 0.27 : 0.73),
                                                          y: diagram.size.height / 2)
                                        }
                                    }
                                }
                                .frame(height: 280)
                            }
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            HStack {
                                bar(width: geometry.size.width * 0.3, height: captionHeight)
                                Spacer()
                                bar(width: geometry.size.width * 0.25, height: captionHeight)
                            }
                            .frame(maxHeight: .infinity, alignment: .top)
                        case .week:
                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(0..<7) { index in
                                    let day = Calendar.current.date(byAdding: .day, value: index, to: week)!
                                    VStack(spacing: 8) {
                                        bar(width: 16, height: captionHeight)
                                        VStack {
                                            Spacer(minLength: 0)
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(placeholder)
                                                .frame(height: chartHeight * [0.5, 0.75, 0.4, 0.9, 0.65, 0.45, 0.6][index])
                                        }
                                        .frame(height: chartHeight)
                                        SummaryDayLabel(date: day, today: today)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(maxHeight: .infinity, alignment: .bottom)
                        case .tags, .totals: EmptyView()
                        }
                    }
                    .padding(20)
                    .statisticCardBackground()
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var placeholder: Color { .primary.opacity(0.08) }

    private func bar(width: CGFloat? = nil, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: min(6, height / 2))
            .fill(placeholder)
            .frame(width: width, height: height)
    }

    private func tagDistribution(size: CGSize) -> some View {
        let diameter = min(size.width * (dynamicTypeSize.isAccessibilitySize ? 0.25 : 0.42), size.height - 32)
        return VStack(alignment: .leading, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize { tagTitle }
            HStack(spacing: 16) {
                Circle().strokeBorder(placeholder, lineWidth: 22)
                    .frame(width: diameter, height: diameter)
                VStack(alignment: .leading, spacing: 10) {
                    if !dynamicTypeSize.isAccessibilitySize { tagTitle }
                    bar(height: captionHeight)
                    bar(width: size.width * 0.24, height: captionHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(16)
    }

    private var tagTitle: some View {
        Text("Tag Distribution").font(.subheadline.bold())
            .fixedSize(horizontal: false, vertical: true)
    }

    private var idealHeight: CGFloat {
        switch kind {
        case .muscle: 40 + titleHeight + 16 + captionHeight + 6 + 280 + 16 + 20
        case .week: 40 + titleHeight + 20 + captionHeight * 2 + 16 + chartHeight
        case .tags, .totals: dynamicTypeSize.isAccessibilitySize ? 380 : 180
        }
    }
}

private struct SummarySkeletonCardLayout: Layout {
    let kind: SummaryCardKind
    let defaultHeight: CGFloat
    let accessibilitySize: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 370
        let naturalHeight: CGFloat
        switch kind {
        case .tags: naturalHeight = max(accessibilitySize ? 300 : 0, (width - 12) / 2)
        case .totals: naturalHeight = accessibilitySize ? width * 2 + 12 : (width - 12) / 2
        default: naturalHeight = defaultHeight
        }
        return CGSize(width: width, height: proposal.height ?? naturalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}

/// The opaque skeleton backing stays in place while real content dissolves over it.
struct SummaryCardReveal: ViewModifier {
    let kind: SummaryCardKind
    let week: Date
    let today: Date
    let isPresented: Bool
    let isFinished: Bool

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: SummaryCardHeightsKey.self, value: [kind: geometry.size.height])
                }
            }
            .compositingGroup()
            .opacity(isPresented ? 1 : 0)
            .background {
                if !isFinished { SummaryCardSkeleton(kind: kind, week: week, today: today) }
            }
    }
}
