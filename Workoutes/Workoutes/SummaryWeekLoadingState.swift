import Foundation
import Observation

struct SummaryWeekLoadRequest: Equatable, Hashable {
    let week: Date
    let isScrolling: Bool
}

/// Keep exactly one live statistics page. A canceled swipe must never start another week's query.
@MainActor
@Observable
final class SummaryWeekLoadingState {
    private(set) var loadedWeek: Date?

    static func skeletonWeeks(around week: Date, through currentWeek: Date, calendar: Calendar = .current) -> Set<Date> {
        Set((-2...2).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset * 7, to: week),
                  date <= currentWeek else { return nil }
            return date
        })
    }

    func load(_ request: SummaryWeekLoadRequest) async {
        guard !request.isScrolling, loadedWeek != request.week else { return }
        do {
            // Let the paging gesture settle and give the loading indicator a frame before
            // creating the SwiftData query and the statistics views on the main actor.
            try await Task.sleep(for: .milliseconds(120))
            try Task.checkCancellation()
            loadedWeek = request.week
        } catch is CancellationError {
            // A newer visible week, another gesture or leaving Home cancels this request.
        } catch {
            assertionFailure("Unexpected week loading cancellation: \(error)")
        }
    }
}
