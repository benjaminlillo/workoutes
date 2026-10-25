import Charts
import SwiftUI

struct WeeklyTagDistributionChart: View {
    let summary: WeeklySummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let distribution = WeeklyTagDistribution(summary: summary)
        WeeklyTagCardLayout(minimumHeight: dynamicTypeSize.isAccessibilitySize ? 300 : 0) {
            GeometryReader { geometry in
                let diameter = min(geometry.size.width * (dynamicTypeSize.isAccessibilitySize ? 0.25 : 0.42), geometry.size.height - 32)
                VStack(alignment: .leading, spacing: 12) {
                    if dynamicTypeSize.isAccessibilitySize {
                        title
                    }
                    HStack(spacing: 16) {
                        donut(distribution)
                            .frame(width: diameter, height: diameter)
                        VStack(alignment: .leading, spacing: 10) {
                            if !dynamicTypeSize.isAccessibilitySize {
                                title
                            }
                            if distribution.entries.isEmpty {
                                Text("No completed exercises")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                ScrollView(.vertical) {
                                    VStack(spacing: 8) {
                                        ForEach(distribution.entries) { entry in
                                            legendRow(entry, distribution: distribution)
                                        }
                                    }
                                }
                                .scrollBounceBehavior(.basedOnSize)
                                .scrollEdgeEffectHidden()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .padding(16)
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .subtleCardShadow()
        .accessibilityIdentifier("weeklyTagDistribution")
    }

    private var title: some View {
        Text("Tag Distribution").font(.subheadline.bold())
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func donut(_ distribution: WeeklyTagDistribution) -> some View {
        if distribution.entries.isEmpty {
            Circle().strokeBorder(.quaternary, lineWidth: 22)
                .accessibilityHidden(true)
        } else {
            Chart(distribution.entries) { entry in
                SectorMark(angle: .value("Tag appearances", entry.count),
                           innerRadius: .ratio(0.62), angularInset: 2)
                    .cornerRadius(4)
                    .foregroundStyle(color(for: entry))
            }
            .chartLegend(.hidden)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Weekly tag distribution")
            .accessibilityValue("\(summary.total) completed exercises, \(distribution.entries.count) categories")
        }
    }

    private func color(for entry: WeeklyTagDistribution.Entry) -> Color {
        entry.colorHex.map { Color(hex: $0) } ?? .gray
    }

    private func legendRow(_ entry: WeeklyTagDistribution.Entry, distribution: WeeklyTagDistribution) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
        return layout {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle().fill(color(for: entry)).frame(width: 8, height: 8)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
                    .accessibilityHidden(true)
                Text(entry.name).font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(distribution.fraction(for: entry), format: .percent.precision(.fractionLength(0)))
                .font(.caption.bold().monospacedDigit())
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.name)
        .accessibilityValue("\(entry.count) tag appearances, \(distribution.fraction(for: entry).formatted(.percent.precision(.fractionLength(0))))")
    }
}

/// One row of the two-column statistics grid, spanning both columns.
private struct WeeklyTagCardLayout: Layout {
    var minimumHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 366
        return CGSize(width: width, height: max(minimumHeight, (width - 12) / 2))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}
