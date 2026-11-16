import Charts
import SwiftUI

struct WeeklyTagDistributionChart: View {
    let distribution: WeeklyTagDistribution

    var body: some View {
        if distribution.entries.isEmpty {
            Circle().strokeBorder(.quaternary, lineWidth: 26)
        } else {
            Chart(distribution.entries) { entry in
                SectorMark(angle: .value("Tag appearances", entry.count),
                           innerRadius: .ratio(0.71), angularInset: distribution.entries.count == 1 ? 0 : 2)
                    .cornerRadius(5)
                    .foregroundStyle(entry.colorHex.map { Color(hex: $0) } ?? .gray)
            }
            .chartLegend(.hidden)
            .accessibilityHidden(true)
        }
    }
}

struct WeeklyTagDistributionLegend: View {
    let distribution: WeeklyTagDistribution
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 8) {
                ForEach(distribution.entries) { entry in
                    legendRow(entry)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectHidden()
        .accessibilityIdentifier("weeklyTagDistribution")
    }

    private func legendRow(_ entry: WeeklyTagDistribution.Entry) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
        return layout {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle().fill(entry.colorHex.map { Color(hex: $0) } ?? .gray).frame(width: 8, height: 8)
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
