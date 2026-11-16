import SwiftUI
import SwiftData
import UIKit

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
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let today = timeline.date
                let currentWeek = WeeklySummary.interval(containing: today).start
                let week = min(WeeklySummary.interval(containing: selectedWeek ?? today).start, currentWeek)
                GeometryReader { geometry in
                    MotivationalScrollView(pull: pull ?? $localPull) {
                        SummaryWeekContent(week: week, today: today, availableHeight: geometry.size.height)
                    }
                }
                .defaultScreenBackground()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        SummaryWeekSelector(week: week, today: today) { newWeek in
                            selectedWeek = newWeek == currentWeek ? nil : newWeek
                        }
                    }
                }
            }
        }
        .overlay {
            if pull == nil { MotivationalPullOverlay(pull: localPull) }
        }
    }
}

private struct SummaryWeekSelector: View {
    let week: Date
    let today: Date
    let select: (Date) -> Void
    @State private var isPresented = false
    @State private var draftWeek = Date.now

    var body: some View {
        let range = WeeklySummary(completions: [], date: week).dateRange(relativeTo: today)
        Button {
            draftWeek = week
            isPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                Text(range).lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 4)
        }
        .accessibilityLabel("Select Week")
        .accessibilityValue(range)
        .accessibilityIdentifier("summaryWeekSelector")
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                ScrollView {
                    SummaryWeekCalendar(week: $draftWeek, today: today)
                        .frame(maxWidth: 440)
                        .padding(.horizontal, 16)
                    Button("This Week") { choose(today) }
                        .padding(.vertical, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
                .navigationTitle("Select Week")
                .navigationSubtitle(WeeklySummary(completions: [], date: draftWeek).dateRange(relativeTo: today))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresented = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { choose(draftWeek) }
                    }
                }
            }
        }
    }

    private func choose(_ date: Date) {
        select(WeeklySummary.interval(containing: date).start)
        isPresented = false
    }
}

private struct SummaryWeekCalendar: UIViewRepresentable {
    @Binding var week: Date
    let today: Date
    @Environment(\.locale) private var locale

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private var currentWeek: DateInterval {
        WeeklySummary.interval(containing: today, calendar: calendar)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.locale = locale
        view.calendar = calendar
        updateRange(of: view)
        view.visibleDateComponents = calendar.dateComponents([.era, .year, .month, .day], from: week)
        view.selectionBehavior = UICalendarSelectionWeekOfYear(delegate: context.coordinator)
        return view
    }

    func updateUIView(_ view: UICalendarView, context: Context) {
        context.coordinator.parent = self
        updateRange(of: view)
        guard let selection = view.selectionBehavior as? UICalendarSelectionWeekOfYear else { return }
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: week)
        let selected = selection.selectedWeekOfYear
        if selected?.weekOfYear != components.weekOfYear || selected?.yearForWeekOfYear != components.yearForWeekOfYear {
            selection.setSelected(components, animated: false)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UICalendarView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return uiView.systemLayoutSizeFitting(CGSize(width: width, height: 0),
                                             withHorizontalFittingPriority: .required,
                                             verticalFittingPriority: .fittingSizeLevel)
    }

    private func updateRange(of view: UICalendarView) {
        // All seven days of the current week belong to the same selectable period.
        let end = currentWeek.end.addingTimeInterval(-1)
        if view.availableDateRange.end != end {
            view.availableDateRange = DateInterval(start: view.availableDateRange.start, end: end)
        }
    }

    final class Coordinator: NSObject, UICalendarSelectionWeekOfYearDelegate {
        var parent: SummaryWeekCalendar

        init(_ parent: SummaryWeekCalendar) { self.parent = parent }

        func week(ofYearSelection selection: UICalendarSelectionWeekOfYear, didSelectWeekOfYear components: DateComponents?) {
            if let week = weekStart(from: components) { parent.week = week }
        }

        func week(ofYearSelection selection: UICalendarSelectionWeekOfYear, canSelectWeekOfYear components: DateComponents?) -> Bool {
            guard let week = weekStart(from: components) else { return false }
            return week <= parent.currentWeek.start
        }

        private func weekStart(from components: DateComponents?) -> Date? {
            guard let year = components?.yearForWeekOfYear, let week = components?.weekOfYear else { return nil }
            let calendar = parent.calendar
            let monday = DateComponents(weekday: calendar.firstWeekday, weekOfYear: week, yearForWeekOfYear: year)
            return calendar.date(from: monday).map { calendar.startOfDay(for: $0) }
        }
    }
}

private struct SummaryWeekContent: View {
    let week: Date
    let today: Date
    let availableHeight: CGFloat
    @Query private var completions: [ExerciseCompletion]

    init(week: Date, today: Date, availableHeight: CGFloat) {
        self.week = week
        self.today = today
        self.availableHeight = availableHeight
        let interval = WeeklySummary.interval(containing: week)
        let start = interval.start
        let end = interval.end
        _completions = Query(filter: #Predicate<ExerciseCompletion> { $0.completedAt >= start && $0.completedAt < end },
                             sort: \ExerciseCompletion.completedAt)
    }

    var body: some View {
        SummaryStatisticsPager(summary: WeeklySummary(completions: completions, date: week),
                               today: today, availableHeight: availableHeight)
    }
}

struct WeeklyExerciseChart: View {
    let summary: WeeklySummary
    let today: Date
    let chartHeight: CGFloat

    private var maximum: Int { max(1, summary.days.map { $0.completions.count }.max() ?? 0) }
    private var blockSpacing: CGFloat { min(3, chartHeight / CGFloat(maximum) * 0.12) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(summary.days) { day in
                VStack(spacing: 8) {
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
