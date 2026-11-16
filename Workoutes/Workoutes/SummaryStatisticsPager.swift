import SwiftUI

enum SummaryStatistic: Int, CaseIterable, Identifiable {
    case muscle, week, tags, totals

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .muscle: "Muscle Activity"
        case .week: "Week Summary"
        case .tags: "Tag Distribution"
        case .totals: "Weekly Totals"
        }
    }
}

struct SummaryStatisticsPager: View {
    let summary: WeeklySummary
    let today: Date
    let availableHeight: CGFloat
    private let distribution: WeeklyTagDistribution
    private let activity: WeeklyMuscleActivity

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @ScaledMetric(relativeTo: .body) private var detailHeight: CGFloat = 158
    @State private var position = ScrollPosition(idType: SummaryStatistic.self)
    @State private var settledPage = SummaryStatistic.muscle
    @State private var detailPage = SummaryStatistic.muscle
    @State private var phase = ScrollPhase.idle
    @State private var detailsVisible = true
    @State private var fadeOutFinished = true

    init(summary: WeeklySummary, today: Date, availableHeight: CGFloat) {
        self.summary = summary
        self.today = today
        self.availableHeight = availableHeight
        let distribution = WeeklyTagDistribution(summary: summary)
        self.distribution = distribution
        activity = WeeklyMuscleActivity(distribution: distribution)
    }

    var body: some View {
        let height = max(availableHeight, detailHeight + 320)
        let visualHeight = height - detailHeight - 52
        ZStack(alignment: .bottom) {
            ScrollView(.horizontal) {
                // There are four pages. Lay them out up front so beginning a swipe
                // never coincides with building the next chart or compositing the bodies.
                HStack(spacing: 0) {
                    ForEach(SummaryStatistic.allCases) { page in
                        visual(page, height: visualHeight)
                            .frame(maxWidth: 520)
                            .padding(.horizontal, 24)
                            .frame(height: visualHeight)
                            .containerRelativeFrame(.horizontal)
                            .frame(height: height, alignment: .top)
                            .contentShape(Rectangle())
                            .accessibilityHidden(page != settledPage)
                            .id(page)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition($position)
            .onScrollPhaseChange { _, nextPhase, context in
                phase = nextPhase
                switch nextPhase {
                case .idle:
                    if let page = page(at: context.geometry) { settledPage = page }
                    showDetailsIfSettled()
                case .interacting, .animating, .decelerating:
                    hideDetails()
                default:
                    break
                }
            }
            .accessibilityIdentifier("summaryStatisticsPager")

            SummaryStatisticDetails(page: detailPage, summary: summary, distribution: distribution, activity: activity)
                .frame(height: detailHeight)
                .frame(maxWidth: 520)
                .padding(.horizontal, 18)
                .compositingGroup()
                .opacity(detailsVisible ? 1 : 0)
                .offset(y: detailsVisible || reduceMotion ? 0 : 6)
                // Keep the card in the same place while the charts move.
                .padding(.bottom, 46)
                .allowsHitTesting(detailsVisible && detailPage == .tags)
                .accessibilityHidden(!detailsVisible)

            pageControls
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func visual(_ page: SummaryStatistic, height: CGFloat) -> some View {
        switch page {
        case .muscle:
            WeeklyMuscleDiagram(activity: activity, maximumHeight: 384)
                .padding(.vertical, 18)
        case .week:
            WeeklyExerciseChart(summary: summary, today: today, chartHeight: min(350, height * 0.77))
        case .tags:
            GeometryReader { geometry in
                let diameter = min(geometry.size.width * 0.83, geometry.size.height * 0.76, 324)
                WeeklyTagDistributionChart(distribution: distribution)
                    .frame(width: diameter, height: diameter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .totals:
            SummaryActiveDays(summary: summary, today: today)
        }
    }

    private var pageControls: some View {
        HStack(spacing: 0) {
            ForEach(SummaryStatistic.allCases) { page in
                Button { move(to: page) } label: {
                    Capsule()
                        .fill(page == settledPage ? Color.primary : Color.secondary.opacity(0.35))
                        .frame(width: page == settledPage ? 17 : 6, height: 6)
                        .frame(width: 38, height: 42)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(page.title))
                .accessibilityAddTraits(page == settledPage ? .isSelected : [])
                .accessibilityIdentifier("summaryStatistic.\(page)")
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: settledPage)
    }

    private func page(at geometry: ScrollGeometry) -> SummaryStatistic? {
        let width = geometry.containerSize.width
        guard width > 0 else { return nil }
        let physicalIndex = Int(((geometry.contentOffset.x + geometry.contentInsets.leading) / width).rounded())
        let index = layoutDirection == .rightToLeft ? SummaryStatistic.allCases.count - 1 - physicalIndex : physicalIndex
        return SummaryStatistic(rawValue: min(max(0, index), SummaryStatistic.allCases.count - 1))
    }

    private func move(to page: SummaryStatistic) {
        guard page != settledPage || phase != .idle else { return }
        if reduceMotion {
            position.scrollTo(id: page)
            settledPage = page
            detailPage = page
        } else {
            withAnimation(.smooth(duration: 0.34)) { position.scrollTo(id: page) }
        }
    }

    private func hideDetails() {
        guard detailsVisible else { return }
        if reduceMotion {
            detailsVisible = false
            return
        }
        fadeOutFinished = false
        withAnimation(.easeOut(duration: 0.12), completionCriteria: .removed) {
            detailsVisible = false
        } completion: {
            fadeOutFinished = true
            showDetailsIfSettled()
        }
    }

    private func showDetailsIfSettled() {
        guard phase == .idle, fadeOutFinished, !detailsVisible else { return }
        detailPage = settledPage
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) { detailsVisible = true }
    }
}

struct SummaryStatisticDetails: View {
    let page: SummaryStatistic
    let summary: WeeklySummary
    let distribution: WeeklyTagDistribution
    let activity: WeeklyMuscleActivity
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(page.title)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)

            switch page {
            case .muscle:
                let trained = activity.entries.filter { $0.icon != nil }
                if trained.isEmpty {
                    emptyLabel("No muscle areas recorded")
                } else {
                    metric(trained.count, label: "Muscle Tags", symbol: "figure.strengthtraining.traditional")
                        .accessibilityValue(Text(trained.map(\.name).joined(separator: ", ")))
                }
            case .week:
                if summary.total == 0 {
                    emptyLabel("No completed exercises")
                } else {
                    metric(summary.total, label: "Completed Exercises", symbol: "checkmark.circle")
                }
            case .tags:
                if distribution.entries.isEmpty {
                    emptyLabel("No completed exercises")
                } else {
                    WeeklyTagDistributionLegend(distribution: distribution)
                }
            case .totals:
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
                layout {
                    metric(summary.total, label: "Completed Exercises", symbol: "checkmark.circle")
                    metric(summary.activeDays, label: "Active Days", symbol: "calendar")
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .statisticCardBackground(cornerRadius: 28)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("summaryStatisticDetails.\(page)")
    }

    private func emptyLabel(_ title: LocalizedStringResource) -> some View {
        Text(title).font(.subheadline).foregroundStyle(.secondary)
    }

    private func metric(_ value: Int, label: LocalizedStringResource, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label {
                Text(value, format: .number)
                    .font(.title2.bold().monospacedDigit())
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct SummaryActiveDays: View {
    let summary: WeeklySummary
    let today: Date

    var body: some View {
        VStack(spacing: 30) {
            Text("\(summary.activeDays) / \(summary.days.count)")
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("Active Days")
                .accessibilityValue(Text("\(summary.activeDays) of \(summary.days.count)"))

            HStack(spacing: 0) {
                ForEach(summary.days) { day in
                    let active = !day.completions.isEmpty
                    VStack(spacing: 9) {
                        Image(systemName: active ? "checkmark" : "minus")
                            .font(.subheadline.bold())
                            .frame(width: 34, height: 34)
                            .foregroundStyle(active ? Color.accentColor : Color.secondary.opacity(0.55))
                            .background(active ? Color.accentColor.opacity(0.13) : .primary.opacity(0.045), in: Circle())
                        SummaryDayLabel(date: day.date, today: today)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide)))
                    .accessibilityValue(active ? Text("Active") : Text("Inactive"))
                }
            }
        }
        .frame(maxWidth: 400)
    }
}
