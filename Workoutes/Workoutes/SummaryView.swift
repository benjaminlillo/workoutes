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
                MotivationalScrollView(pull: pull ?? $localPull) {
                    VStack(spacing: 4) {
                        SummaryWeekHeader(week: selectedWeek ?? timeline.date, today: timeline.date)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                            .padding(.bottom, 16)
                        WeeklySummaryPager(today: timeline.date, selectedWeek: $selectedWeek)
                    }
                    .padding(.bottom, 16)
                }
                .scrollClipDisabled()
                .scrollEdgeEffectStyle(.soft, for: .top)
                .defaultScreenBackground()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .overlay {
            if pull == nil {
                MotivationalPullOverlay(pull: localPull)
            }
        }
    }
}

struct SummaryWeekHeader: View {
    let week: Date
    let today: Date

    var body: some View {
        let summary = WeeklySummary(completions: [], date: week)
        let isCurrentWeek = summary.interval.start == WeeklySummary.interval(containing: today).start
        VStack(alignment: .leading, spacing: 6) {
            Text(isCurrentWeek ? "This Week" : "Week Summary")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(summary.dateRange(relativeTo: today))
                .font(.system(.title, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("summaryWeekHeader")
    }
}

/// Each visible page fetches its own week; extending the range keeps the same date IDs.
struct WeeklySummaryPager: View {
    let today: Date
    @Binding var selectedWeek: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var centeredWeek: Date?
    @State private var oldestWeek: Date

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
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                ForEach(weeks, id: \.self) { week in
                    WeeklySummaryPage(week: week, today: today)
                        .containerRelativeFrame(.horizontal)
                        .id(week)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $centeredWeek)
        .defaultScrollAnchor(.trailing, for: .initialOffset)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .fixedSize(horizontal: false, vertical: true)
        .onScrollGeometryChange(for: Int.self) { scroll in
            guard scroll.containerSize.width > 0 else { return weeks.count - 1 }
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
        VStack(spacing: 16) {
            WeeklyMuscleActivityCard(summary: summary)
            WeeklyExerciseChart(summary: summary, today: today)
            WeeklyTagDistributionChart(summary: summary)
            SummaryStatistics(summary: summary)
        }
        .padding(16)
        .fixedSize(horizontal: false, vertical: true)
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
                        Text(day.date, format: .dateTime.weekday(.narrow))
                            .font(.caption.weight(Calendar.current.isDate(day.date, inSameDayAs: today) ? .bold : .regular))
                            .foregroundStyle(Calendar.current.isDate(day.date, inSameDayAs: today) ? Color.accentColor : .secondary)
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
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .subtleCardShadow()
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
    let value: Int
    let symbol: String

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: symbol).foregroundStyle(.secondary)
                    Text("\(value)").font(.largeTitle.bold()).monospacedDigit()
                    Text(title).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .subtleCardShadow()
            .accessibilityElement(children: .combine)
    }
}
