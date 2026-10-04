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
    var body: some View {
        NavigationStack {
            // Refreshes after midnight/time-zone changes, including when this tab stays open.
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                SummaryWeekView(date: timeline.date)
            }
            .transparentNavigationChrome()
            .navigationTitle("Summary")
        }
    }
}

private struct SummaryWeekView: View {
    let date: Date
    @Query private var completions: [ExerciseCompletion]

    init(date: Date) {
        self.date = date
        let interval = WeeklySummary.interval(containing: date)
        let start = interval.start
        let end = interval.end
        _completions = Query(filter: #Predicate<ExerciseCompletion> { $0.completedAt >= start && $0.completedAt < end },
                             sort: \ExerciseCompletion.completedAt)
    }

    var body: some View {
        ScrollView {
            SummaryDashboard(summary: WeeklySummary(completions: completions, date: date), today: date)
                .padding(16)
        }
        .defaultScreenBackground()
    }
}

struct SummaryDashboard: View {
    let summary: WeeklySummary
    let today: Date
    @ScaledMetric(relativeTo: .caption) private var chartHeight = 190
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var maximum: Int { max(1, summary.days.map { $0.completions.count }.max() ?? 0) }
    private var blockSpacing: CGFloat { min(2, chartHeight / CGFloat(maximum) * 0.12) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week").font(.title3.bold())
                    Text("\(summary.interval.start.formatted(.dateTime.month(.abbreviated).day())) – \(summary.days.last!.date.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(summary.days) { day in
                        VStack(spacing: 8) {
                            Text("\(day.completions.count)")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                VStack(spacing: blockSpacing) {
                                    ForEach(day.completions.reversed()) { completion in
                                        HStack(spacing: 0) {
                                            let colors = completion.tagColors
                                            if colors.isEmpty {
                                                Color.gray.opacity(0.5)
                                            } else {
                                                ForEach(Array(colors.enumerated()), id: \.offset) { _, hex in
                                                    Color(hex: hex)
                                                }
                                            }
                                        }
                                        .frame(height: (chartHeight - CGFloat(maximum - 1) * blockSpacing) / CGFloat(maximum))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
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
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month().day()))
                        .accessibilityValue("\(day.completions.count) completed exercises. \(day.completions.map(\.exerciseTitle).joined(separator: ", "))")
                    }
                }
                .accessibilityIdentifier("weeklyExerciseChart")
                Text(summary.total == 0 ? "No completed exercises this week. Start an exercise and stop after more than 10 seconds to record it." : "Each block is one completed exercise. Colors follow its current tags.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .subtleCardBorder(cornerRadius: 24)

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                SummaryStatisticCard(title: "Completed Exercises", value: summary.total, symbol: "checkmark.circle")
                SummaryStatisticCard(title: "Active Days", value: summary.activeDays, symbol: "calendar")
            }
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
            .subtleCardBorder(cornerRadius: 24)
            .accessibilityElement(children: .combine)
    }
}
