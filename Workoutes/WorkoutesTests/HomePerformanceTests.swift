import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class HomePerformanceTests: XCTestCase {
    private func home() async throws -> (UIWindow, UIScrollView) {
        let store = try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let icons: [MuscleIcon] = [.chest, .back, .shoulders, .arms, .core, .quadriceps, .glutes, .calves]
        let colors = ["F08B4F", "55B8AD", "A280D9", "E46F94", "648DE8", "8DA86B", "DCA756", "6A8CA9"]
        let today = Date.now
        let week = WeeklySummary.interval(containing: today).start
        for (index, icon) in icons.enumerated() {
            let tag = Tag(name: icon.name, colorHex: colors[index], iconName: icon.rawValue)
            let exercise = WorkoutExercise(title: icon.name, subtitle: "", details: "", numberOfSets: 3,
                                           reps: 10, increaseLoadNextTime: false, weight: 20)
            exercise.tags = [tag]
            store.mainContext.insert(tag)
            store.mainContext.insert(exercise)
            for offset in 0..<13 {
                for completion in 0..<5 {
                    let date = Calendar.current.date(byAdding: .day, value: -offset * 7 + completion, to: week)!
                    store.mainContext.insert(ExerciseCompletion(id: "\(index)-\(offset)-\(completion)", completedAt: date, exercise: exercise))
                }
            }
        }
        try store.mainContext.save()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: SummaryView().modelContainer(store))
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(900))
        window.layoutIfNeeded()
        func verticalScroll(_ view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height { return scroll }
            return view.subviews.compactMap { verticalScroll($0) }.first
        }
        let scroll = try XCTUnwrap(verticalScroll(try XCTUnwrap(window.rootViewController?.view)))
        return (window, scroll)
    }

    func testPopulatedHomeScrollRenderingPerformance() async throws {
        let (window, scroll) = try await home()
        defer { window.isHidden = true }
        measureScroll(window: window, scroll: scroll, entering: false)
    }

    func testMuscleCardReentryRenderingPerformance() async throws {
        let (window, scroll) = try await home()
        defer { window.isHidden = true }
        measureScroll(window: window, scroll: scroll, entering: true)
    }

    private func measureScroll(window: UIWindow, scroll: UIScrollView, entering: Bool) {
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        measure(metrics: [XCTClockMetric()], options: options) {
            for step in 0..<16 {
                scroll.setContentOffset(CGPoint(x: 0, y: CGFloat(entering ? 15 - step : step) * 35), animated: false)
                window.layoutIfNeeded()
                _ = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            }
        }
    }
}
