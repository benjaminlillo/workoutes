import SwiftUI
import SwiftData

struct WeeklyDay: Identifiable {
    var id: Date { date }
    let date: Date
    let completions: [ExerciseCompletion]
}

struct WeeklySummary {
    let interval: DateInterval
    let days: [WeeklyDay]
    var total: Int { days.reduce(0) { $0 + $1.completions.count } }
    var activeDays: Int { days.filter { !$0.completions.isEmpty }.count }

    func dateRange(relativeTo today: Date, calendar: Calendar = .current) -> String {
        let lastDay = days.last!.date
        let showYear = !calendar.isDate(interval.start, equalTo: today, toGranularity: .year)
            || !calendar.isDate(lastDay, equalTo: today, toGranularity: .year)
        let format = showYear ? Date.FormatStyle.dateTime.month(.abbreviated).day().year()
            : Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "\(interval.start.formatted(format)) – \(lastDay.formatted(format))"
    }

    static func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let today = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: today) + 5) % 7
        // A DST transition can make today's first instant 01:00 rather than 00:00.
        // Normalize both boundaries after arithmetic so we never lose Monday's first hour.
        let monday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: today)!)
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 7, to: monday)!)
        return DateInterval(start: monday, end: end)
    }

    init(completions: [ExerciseCompletion], date: Date, calendar: Calendar = .current) {
        let week = Self.interval(containing: date, calendar: calendar)
        interval = week
        let inWeek = completions.filter { $0.completedAt >= week.start && $0.completedAt < week.end }
        days = (0..<7).map { offset in
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: week.start)!)
            return WeeklyDay(date: day, completions: inWeek.filter {
                calendar.isDate($0.completedAt, inSameDayAs: day)
            }.sorted {
                $0.completedAt == $1.completedAt ? $0.id < $1.id : $0.completedAt < $1.completedAt
            })
        }
    }
}

struct SummaryView: View {
    var pull: Binding<MotivationalPullState>? = nil
    @State private var localPull = MotivationalPullState()
    @State private var selectedWeek: Date?

    var body: some View {
        NavigationStack {
            // Refreshes after midnight/time-zone changes, including when this tab stays open.
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let summary = WeeklySummary(completions: [], date: selectedWeek ?? timeline.date)
                let isCurrentWeek = summary.interval.start == WeeklySummary.interval(containing: timeline.date).start
                MotivationalScrollView(pull: pull ?? $localPull) {
                    WeeklySummaryPager(today: timeline.date, selectedWeek: $selectedWeek)
                        .padding(.bottom, 16)
                }
                .scrollClipDisabled()
                .scrollEdgeEffectStyle(.soft, for: .top)
                .defaultScreenBackground()
                .navigationTitle(summary.dateRange(relativeTo: timeline.date))
                .navigationSubtitle(Text(isCurrentWeek ? "This Week" : "Week Summary"))
                .navigationBarTitleDisplayMode(.large)
            }
        }
        .overlay {
            if pull == nil {
                MotivationalPullOverlay(pull: localPull)
            }
        }
    }
}

/// Date targets are lightweight. Only the settled week creates a query and real statistics.
struct WeeklySummaryPager: View {
    let today: Date
    @Binding var selectedWeek: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var centeredWeek: Date?
    @State private var oldestWeek: Date
    @State private var pageHeights: [Date: CGFloat] = [:]
    @State private var cardHeights: [SummaryCardKind: CGFloat] = [:]
    @State private var loading = SummaryWeekLoadingState()
    @State private var isPaging = false
    @ScaledMetric(relativeTo: .body) private var initialPageHeight: CGFloat = 1200

    init(today: Date, selectedWeek: Binding<Date?>) {
        self.today = today
        _selectedWeek = selectedWeek
        let selected = WeeklySummary.interval(containing: selectedWeek.wrappedValue ?? today).start
        _centeredWeek = State(initialValue: selected)
        _oldestWeek = State(initialValue: Calendar.current.date(byAdding: .day, value: -12 * 7, to: selected)!)
    }

    private var currentWeek: Date { WeeklySummary.interval(containing: today).start }
    private var weeks: [Date] {
        let calendar = Calendar.current
        let first = WeeklySummary.interval(containing: oldestWeek).start
        let count = (calendar.dateComponents([.day], from: first, to: currentWeek).day ?? 0) / 7
        return (0...max(0, count)).compactMap { calendar.date(byAdding: .day, value: $0 * 7, to: first) }
    }

    var body: some View {
        let dates = weeks
        let requestedWeek = selectedWeek ?? currentWeek
        let request = SummaryWeekLoadRequest(week: requestedWeek, isScrolling: isPaging)
        let skeletonWeeks = SummaryWeekLoadingState.skeletonWeeks(around: requestedWeek, through: currentWeek)
        let pageHeight = loading.loadedWeek.flatMap { pageHeights[$0] }
            ?? pageHeights.values.max() ?? initialPageHeight
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                ForEach(dates, id: \.self) { week in
                    Group {
                        if loading.loadedWeek == week {
                            WeeklySummaryPage(week: week, today: today)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _, height in
                                    guard height > 0, abs((pageHeights[week] ?? 0) - height) > 0.5 else { return }
                                    pageHeights[week] = height
                                }
                        } else if skeletonWeeks.contains(week) {
                            SummaryWeekSkeleton(week: week, today: today, heights: cardHeights)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(height: pageHeight, alignment: .top)
                        } else {
                            Color.clear.frame(height: pageHeight)
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                    .id(week)
                }
            }
            .frame(height: pageHeight, alignment: .top)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $centeredWeek)
        .defaultScrollAnchor(.trailing, for: .initialOffset)
        .scrollIndicators(.hidden)
        .frame(height: pageHeight)
        .onPreferenceChange(SummaryCardHeightsKey.self) { heights in
            if !heights.isEmpty, heights != cardHeights { cardHeights = heights }
        }
        .onScrollPhaseChange { _, phase in
            isPaging = phase.isScrolling
        }
        .task(id: request) {
            await loading.load(request)
            guard !Task.isCancelled, !isPaging, loading.loadedWeek == request.week,
                  (selectedWeek ?? currentWeek) == request.week else { return }
            // Preserve the settled date when a loading target is replaced by real content.
            // Updating both states in this transaction also covers accessibility/programmatic scrolling.
            if centeredWeek != request.week {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) { centeredWeek = request.week }
            }
        }
        .onScrollGeometryChange(for: Int.self) { scroll in
            guard scroll.containerSize.width > 0 else { return -1 }
            return Int(((scroll.contentOffset.x + scroll.contentInsets.leading) / scroll.containerSize.width).rounded())
        } action: { _, index in
            guard weeks.indices.contains(index) else { return }
            let week = weeks[index]
            selectedWeek = week == currentWeek ? nil : week
        }
        .accessibilityIdentifier("weeklySummaryPager")
        .accessibilityAction(named: "Previous Week") { moveWeek(by: -1) }
        .accessibilityAction(named: "Next Week") { moveWeek(by: 1) }
        .onChange(of: centeredWeek) { _, week in
            guard let week, week <= currentWeek else { return }
            // The current week follows the clock; historical weeks stay on their dates.
            selectedWeek = week == currentWeek ? nil : week
            if let threshold = Calendar.current.date(byAdding: .day, value: 4 * 7, to: oldestWeek), week <= threshold {
                oldestWeek = Calendar.current.date(byAdding: .day, value: -12 * 7, to: oldestWeek)!
            }
        }
        .onChange(of: currentWeek) { _, week in
            if selectedWeek == nil { centeredWeek = week }
        }
    }

    private func moveWeek(by offset: Int) {
        guard let target = Calendar.current.date(byAdding: .day, value: offset * 7, to: centeredWeek ?? currentWeek),
              target <= currentWeek else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.32)) {
            centeredWeek = target
        }
    }
}

private struct WeeklySummaryPage: View {
    let week: Date
    let today: Date
    @Query private var completions: [ExerciseCompletion]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false
    @State private var isFinished = false

    init(week: Date, today: Date) {
        self.week = week
        self.today = today
        let interval = WeeklySummary.interval(containing: week)
        let start = interval.start
        let end = interval.end
        _completions = Query(filter: #Predicate<ExerciseCompletion> { $0.completedAt >= start && $0.completedAt < end },
                             sort: \ExerciseCompletion.completedAt)
    }

    var body: some View {
        let summary = WeeklySummary(completions: completions, date: week)
        let distribution = WeeklyTagDistribution(summary: summary)
        VStack(spacing: 16) {
            WeeklyMuscleActivityCard(summary: summary, distribution: distribution)
                .modifier(SummaryCardReveal(kind: .muscle, week: week, today: today, isPresented: isPresented, isFinished: isFinished))
            WeeklyExerciseChart(summary: summary, today: today)
                .modifier(SummaryCardReveal(kind: .week, week: week, today: today, isPresented: isPresented, isFinished: isFinished))
            WeeklyTagDistributionChart(summary: summary, distribution: distribution)
                .modifier(SummaryCardReveal(kind: .tags, week: week, today: today, isPresented: isPresented, isFinished: isFinished))
            SummaryStatistics(summary: summary)
                .modifier(SummaryCardReveal(kind: .totals, week: week, today: today, isPresented: isPresented, isFinished: isFinished))
        }
        .padding(16)
        .fixedSize(horizontal: false, vertical: true)
        .allowsHitTesting(isPresented)
        .accessibilityHidden(!isPresented)
        .task {
            guard !isPresented else { return }
            do {
                // Lay out the fetched statistics and prepare their images before fading them in.
                try await Task.sleep(for: .milliseconds(32))
                try Task.checkCancellation()
                withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.28)) {
                    isPresented = true
                } completion: {
                    isFinished = true
                }
            } catch is CancellationError {
                // The user moved to another week before this page was ready.
            } catch {
                assertionFailure("Unexpected week presentation cancellation: \(error)")
            }
        }
        .accessibilityIdentifier("summaryWeekPage")
    }
}

struct WeeklyExerciseChart: View {
    let summary: WeeklySummary
    let today: Date
    @ScaledMetric(relativeTo: .caption) private var chartHeight = 190

    private var maximum: Int { max(1, summary.days.map { $0.completions.count }.max() ?? 0) }
    private var blockSpacing: CGFloat { min(2, chartHeight / CGFloat(maximum) * 0.12) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Week Summary").font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(summary.days) { day in
                    VStack(spacing: 8) {
                        Text("\(day.completions.count)")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            VStack(spacing: blockSpacing) {
                                ForEach(day.completions.reversed()) { completion in
                                    WeeklyExerciseBlock(completion: completion,
                                                        height: (chartHeight - CGFloat(maximum - 1) * blockSpacing) / CGFloat(maximum))
                                }
                                if day.completions.isEmpty {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(.quaternary).frame(height: 3)
                                }
                            }
                        }
                        .frame(height: chartHeight)
                        SummaryDayLabel(date: day.date, today: today)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month().day()))
                    .accessibilityValue("\(day.completions.count) completed exercises")
                }
            }
            .accessibilityIdentifier("weeklyExerciseChart")
        }
        .padding(20)
        .statisticCardBackground()
    }
}

struct SummaryDayLabel: View {
    let date: Date
    let today: Date

    var body: some View {
        let isToday = Calendar.current.isDate(date, inSameDayAs: today)
        Text(date, format: .dateTime.weekday(.narrow))
            .font(.caption.weight(isToday ? .bold : .regular))
            .foregroundStyle(isToday ? Color.accentColor : .secondary)
    }
}

struct SummaryStatistics: View {
    let summary: WeeklySummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            SummaryStatisticCard(title: String(localized: "Completed Exercises"), value: summary.total, symbol: "checkmark.circle")
            SummaryStatisticCard(title: String(localized: "Active Days"), value: summary.activeDays, symbol: "calendar")
        }
    }
}

struct SummaryStatisticCard: View {
    let title: String
    let value: Int?
    let symbol: String

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .aspectRatio(1, contentMode: .fit)
            .subtleCardShadow()
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: symbol).foregroundStyle(.secondary)
                    Text("\(value ?? 0)").font(.largeTitle.bold()).monospacedDigit()
                        .redacted(reason: value == nil ? .placeholder : [])
                    Text(title).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .accessibilityElement(children: .combine)
    }
}
