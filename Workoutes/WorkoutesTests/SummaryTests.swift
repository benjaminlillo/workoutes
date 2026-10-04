import ActivityKit
import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class SummaryTests: XCTestCase {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func exercise(_ title: String = "Bench Press") -> WorkoutExercise {
        WorkoutExercise(title: title, subtitle: "Chest", details: "", numberOfSets: 3, reps: 10,
                        increaseLoadNextTime: false, weight: 20)
    }

    func testStrictThresholdAcrossCardNavbarAndLiveActivity() async throws {
        for surface in 0..<3 {
            for duration in [9.999, 10.0, 10.001] {
                let store = try container()
                let context = store.mainContext
                let item = exercise()
                context.insert(item)
                var now = Date(timeIntervalSince1970: 1_800_000_000)
                let controller = ExerciseActivityController(context: context, now: { now }, liveActivitiesEnabled: false)
                controller.advanceState(item, context: context)
                await controller.waitForPendingUpdates()
                let sessionID = try XCTUnwrap(controller.activeSessionID)
                now = now.addingTimeInterval(duration)
                switch surface {
                case 0: controller.advanceState(item, context: context)
                case 1: controller.toggle(item, context: context)
                default:
                    try await controller.performLiveActivityAction(exerciseID: item.activityID, sessionID: sessionID,
                                                                   complete: true, context: context)
                }
                await controller.waitForPendingUpdates()
                XCTAssertNil(controller.errorMessage)
                XCTAssertNil(controller.activeExerciseID)
                XCTAssertEqual(item.isDone, duration > 10)
                let records = try context.fetch(FetchDescriptor<ExerciseCompletion>())
                XCTAssertEqual(records.count, duration > 10 ? 1 : 0)
                XCTAssertEqual(records.first?.id, duration > 10 ? sessionID : nil)
                XCTAssertEqual(records.first?.completedAt, duration > 10 ? now : nil)
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseSession>()), 0)
                // Re-delivery of the same intent never records twice.
                try await controller.performLiveActivityAction(exerciseID: item.activityID, sessionID: sessionID,
                                                               complete: true, context: context)
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), records.count)
            }
        }
    }

    func testSwitchCancelsAndStaleIntentCannotStopANewerAttemptOfSameExercise() async throws {
        let store = try container()
        let context = store.mainContext
        let first = exercise("First")
        let second = exercise("Second")
        context.insert(first); context.insert(second)
        var now = Date.now
        let controller = ExerciseActivityController(context: context, now: { now }, liveActivitiesEnabled: false)
        controller.toggle(first, context: context)
        await controller.waitForPendingUpdates()
        let oldID = controller.activeSessionID
        now = now.addingTimeInterval(120)
        controller.toggle(second, context: context)
        await controller.waitForPendingUpdates()
        XCTAssertFalse(first.isDone)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 0)
        XCTAssertEqual(controller.activeStartedAt, now)
        controller.toggle(first, context: context)
        await controller.waitForPendingUpdates()
        XCTAssertNotEqual(controller.activeSessionID, oldID)
        try await controller.performLiveActivityAction(exerciseID: first.activityID, sessionID: oldID,
                                                       complete: true, context: context)
        XCTAssertTrue(controller.isActive(first))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseSession>()), 1)
    }

    func testRecoveryWithNoLiveActivityAndRepeatedCompletionsSurviveResetAndDeletion() async throws {
        let store = try container()
        let context = store.mainContext
        let item = exercise()
        let tag = Tag(name: "Chest", colorHex: "FF8800")
        context.insert(item); context.insert(tag)
        item.tags = [tag]
        var now = Date.now
        let startedAt = now
        let original = ExerciseActivityController(context: context, now: { now }, liveActivitiesEnabled: false)
        original.toggle(item, context: context)
        await original.waitForPendingUpdates()
        let sessionID = original.activeSessionID
        let restored = ExerciseActivityController(context: context, now: { now }, liveActivitiesEnabled: false)
        XCTAssertTrue(restored.isActive(item))
        XCTAssertEqual(restored.activeStartedAt, startedAt)
        XCTAssertEqual(restored.activeSessionID, sessionID)
        XCTAssertEqual(restored.content(for: item).startedAt, startedAt)
        now = now.addingTimeInterval(3_600)
        restored.toggle(item, context: context)
        await restored.waitForPendingUpdates()
        XCTAssertTrue(item.isDone)
        restored.advanceState(item, context: context) // Reset must keep history.
        XCTAssertFalse(item.isDone)
        restored.advanceState(item, context: context)
        await restored.waitForPendingUpdates()
        now = now.addingTimeInterval(11)
        restored.advanceState(item, context: context)
        await restored.waitForPendingUpdates()
        let records = try context.fetch(FetchDescriptor<ExerciseCompletion>())
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(Set(records.map(\.id)).count, 2)
        tag.colorHex = "5599FF"
        XCTAssertEqual(records.first?.tagColors, ["5599FF"])
        item.title = "Renamed"
        XCTAssertTrue(records.allSatisfy { $0.exerciseTitle == "Renamed" })
        context.delete(tag)
        try context.save()
        XCTAssertTrue(records.allSatisfy { $0.tagColors.isEmpty })
        context.delete(item)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 2)
        XCTAssertTrue(records.allSatisfy { $0.exercise == nil && $0.exerciseTitle == "Exercise deleted" })
    }

    func testDeletingActiveExerciseCancelsWithoutHistory() async throws {
        let store = try container()
        let context = store.mainContext
        let item = exercise()
        context.insert(item)
        let controller = ExerciseActivityController(context: context, liveActivitiesEnabled: false)
        controller.toggle(item, context: context)
        await controller.waitForPendingUpdates()
        context.delete(item)
        controller.synchronize(exercises: [])
        await controller.waitForPendingUpdates()
        XCTAssertNil(controller.activeExerciseID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseSession>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 0)
    }

    func testWeekIsMondayThroughSundayWithLocalFinishDatesAndDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Santiago"))
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 18))!
        let interval = WeeklySummary.interval(containing: date, calendar: calendar)
        XCTAssertEqual(calendar.component(.weekday, from: interval.start), 2)
        let item = exercise()
        let records = [interval.start.addingTimeInterval(-1), interval.start,
                       interval.end.addingTimeInterval(-1), interval.end].enumerated().map {
            ExerciseCompletion(id: "\($0.offset)", completedAt: $0.element, exercise: item)
        }
        let summary = WeeklySummary(completions: records, date: date, calendar: calendar)
        XCTAssertEqual(summary.days.count, 7)
        XCTAssertEqual(summary.total, 2)
        XCTAssertEqual(summary.activeDays, 2)
        XCTAssertEqual(summary.days.first?.completions.count, 1)
        XCTAssertEqual(summary.days.last?.completions.count, 1)
        let nextWeek = WeeklySummary(completions: records, date: interval.end, calendar: calendar)
        XCTAssertEqual(nextWeek.total, 1)
        XCTAssertEqual(nextWeek.days.first?.completions.count, 1)
    }

    func testBackupUpsertsCatalogAndPreservesExistingHistory() throws {
        let source = try container()
        let context = source.mainContext
        let item = exercise()
        let workout = Workout(name: "Push")
        let tag = Tag(name: "Chest", colorHex: "FF8800")
        context.insert(item); context.insert(workout); context.insert(tag)
        item.workouts = [workout]; item.tags = [tag]
        let completion = ExerciseCompletion(id: "record", completedAt: .now, exercise: item)
        context.insert(completion)
        context.insert(ExerciseSession(exercise: item, startedAt: .now))
        let withoutHistory = try DataBackup.export(from: context, includeHistory: false)
        let withHistory = try DataBackup.export(from: context, includeHistory: true)
        XCTAssertFalse(String(decoding: withoutHistory, as: UTF8.self).contains("history"))
        XCTAssertFalse(String(decoding: withHistory, as: UTF8.self).contains("startedAt"))
        let target = try container()
        let destination = target.mainContext
        let untouched = exercise("Keep Me")
        destination.insert(untouched)
        try DataBackup.importData(withHistory, into: destination)
        try DataBackup.importData(withHistory, into: destination)
        XCTAssertEqual(try destination.fetchCount(FetchDescriptor<WorkoutExercise>()), 2)
        XCTAssertEqual(try destination.fetchCount(FetchDescriptor<Workout>()), 1)
        XCTAssertEqual(try destination.fetchCount(FetchDescriptor<Tag>()), 1)
        XCTAssertEqual(try destination.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
        XCTAssertEqual(try destination.fetchCount(FetchDescriptor<ExerciseSession>()), 0)
        let imported = try XCTUnwrap(try destination.fetch(FetchDescriptor<WorkoutExercise>()).first { $0.stableID == item.stableID })
        XCTAssertEqual(imported.workouts.first?.stableID, workout.stableID)
        XCTAssertEqual(imported.tags.first?.stableID, tag.stableID)
        item.title = "Updated"; item.weight = 30; item.tags = []
        workout.name = "Updated Push"; tag.colorHex = "00FF00"
        completion.completedAt = .distantPast // Existing history is immutable on import.
        try DataBackup.importData(DataBackup.export(from: context, includeHistory: true), into: destination)
        XCTAssertEqual(imported.title, "Updated")
        XCTAssertEqual(imported.weight, 30)
        XCTAssertTrue(imported.tags.isEmpty)
        XCTAssertEqual(imported.workouts.first?.name, "Updated Push")
        XCTAssertNotEqual(try destination.fetch(FetchDescriptor<ExerciseCompletion>()).first?.completedAt, .distantPast)
        // Older JSON (no history) remains idempotent and doesn't erase existing history.
        try DataBackup.importData(withoutHistory, into: destination)
        try DataBackup.importData(withoutHistory, into: destination)
        XCTAssertEqual(try destination.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
        XCTAssertEqual(try destination.fetchCount(FetchDescriptor<WorkoutExercise>()), 2)
    }

    func testImportValidationDoesNotPartiallyChangeCatalog() throws {
        let store = try container()
        let context = store.mainContext
        let data = Data("""
        {"workouts":[{"id":"w","name":"New"}],"tags":[],"exercises":[{"id":"e","title":"Bad","subtitle":"","details":"","numberOfSets":3,"reps":10,"increaseLoadNextTime":false,"isDone":false,"weight":20,"workouts":[],"tags":[{"id":"missing"}]}]}
        """.utf8)
        XCTAssertThrowsError(try DataBackup.importData(data, into: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Workout>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutExercise>()), 0)
        let duplicate = Data("""
        {"workouts":[{"id":"w","name":"First"},{"id":"w","name":"Duplicate"}],"tags":[],"exercises":[]}
        """.utf8)
        XCTAssertThrowsError(try DataBackup.importData(duplicate, into: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Workout>()), 0)
    }

    func testStatisticCardsAreSquareRegardlessOfTitleLength() throws {
        for (title, symbol) in [("Completed Exercises", "checkmark.circle"), ("Active Days", "calendar")] {
            for width in [CGFloat(160), 177, 200] {
                let renderer = ImageRenderer(content: SummaryStatisticCard(title: title, value: 7, symbol: symbol)
                    .frame(width: width))
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertEqual(image.size.width, width, accuracy: 0.5)
                XCTAssertEqual(image.size.height, width, accuracy: 0.5)
            }
        }
    }

    func testMotivationalOverlayRendersAcrossNativeChrome() async throws {
        let store = try container()
        let controller = ExerciseActivityController(context: store.mainContext, liveActivitiesEnabled: false)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)

        for (name, distance, delay) in [("pull", CGFloat(110), 0.2), ("burst", CGFloat(121), 1.3)] {
            var pull = MotivationalPullState()
            pull.beginGesture()
            pull.updateDistance(distance)
            if name == "burst" {
                pull.endGesture()
                pull.updateDistance(0)
            }
            // Seed a visual snapshot while preserving the real TabView and its native bars.
            let root = UIHostingController(rootView: ContentView()
                .overlay { MotivationalPullOverlay(pull: pull) }
                .environment(controller).environment(ExerciseBackgroundStore()).modelContainer(store))
            let window = UIWindow(windowScene: scene)
            window.rootViewController = root
            window.overrideUserInterfaceStyle = .light
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            try await Task.sleep(for: .milliseconds(100))

            func findScroll(_ view: UIView) -> UIScrollView? {
                if let scroll = view as? UIScrollView { return scroll }
                return view.subviews.compactMap { findScroll($0) }.first
            }
            let scroll = try XCTUnwrap(findScroll(root.view))
            if name == "pull" {
                scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top - distance), animated: false)
            }
            try await Task.sleep(for: .seconds(delay))
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-motivational-\(name).png"))
        }
    }

    func testSummaryRendersEmptyPopulatedAndAccessibleLayouts() throws {
        let date = Date.now
        let week = WeeklySummary.interval(containing: date)
        let first = exercise()
        first.tags = [Tag(name: "Chest", colorHex: "FF8800"), Tag(name: "Strength", colorHex: "5599FF")]
        let records = (0..<5).map {
            ExerciseCompletion(id: "\($0)", completedAt: Calendar.current.date(byAdding: .day, value: $0 % 3, to: week.start)!,
                               exercise: $0 == 4 ? nil : first)
        }
        for (name, history, scheme, size) in [
            ("empty", [ExerciseCompletion](), ColorScheme.light, DynamicTypeSize.large),
            ("populated", records, .light, .large),
            ("dark", records, .dark, .large),
            ("accessible", records, .light, .accessibility3)
        ] {
            let renderer = ImageRenderer(content: SummaryDashboard(summary: WeeklySummary(completions: history, date: date), today: date)
                .padding(16).frame(width: 398).background(DefaultScreenBackground())
                .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertGreaterThan(image.size.height, 300)
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-summary-\(name).png"))
        }
    }

    func testFullTabIntegrationPreservesAccessoryAndRendersSessionAndSummary() async throws {
        let store = try container()
        let context = store.mainContext
        let item = exercise()
        item.tags = [Tag(name: "Chest", colorHex: "FF8800"), Tag(name: "Strength", colorHex: "5599FF")]
        context.insert(item)
        try context.save()
        var now = Date.now
        let controller = ExerciseActivityController(context: context, now: { now }, liveActivitiesEnabled: false)
        let root = UIHostingController(rootView: ContentView()
            .environment(controller).environment(ExerciseBackgroundStore()).modelContainer(store))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.overrideUserInterfaceStyle = .light
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        func findTabs(_ root: UIViewController) -> UITabBarController? {
            if let tabs = root as? UITabBarController { return tabs }
            return root.children.compactMap { findTabs($0) }.first
        }
        for _ in 0..<100 {
            if findTabs(root)?.bottomAccessory != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let tabs = try XCTUnwrap(findTabs(root))
        XCTAssertEqual(tabs.tabs.count, 4)
        let accessory = try XCTUnwrap(tabs.bottomAccessory)

        func snapshot(_ name: String) throws {
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-tabs-\(name).png"))
        }
        try await Task.sleep(for: .milliseconds(200))
        try snapshot("summary-empty")
        await controller.waitForPendingUpdates()
        controller.toggle(item, context: context)
        await controller.waitForPendingUpdates()
        tabs.selectedTab = tabs.tabs[2]
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(tabs.selectedTab === tabs.tabs[2])
        XCTAssertTrue(tabs.bottomAccessory === accessory)
        XCTAssertTrue(controller.isActive(item))
        try snapshot("active")
        now = now.addingTimeInterval(11)
        controller.toggle(item, context: context)
        await controller.waitForPendingUpdates()
        tabs.selectedTab = tabs.tabs[0]
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(tabs.selectedTab === tabs.tabs[0])
        XCTAssertTrue(tabs.bottomAccessory === accessory)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
        XCTAssertTrue(item.isDone)
        try snapshot("summary-completed")
        window.overrideUserInterfaceStyle = .dark
        try await Task.sleep(for: .milliseconds(200))
        try snapshot("summary-dark")
    }
}
