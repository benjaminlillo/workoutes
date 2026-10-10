import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class ExerciseHistoryTests: XCTestCase {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testDeletingSelectedEntryPersistsWithoutChangingExerciseOrActiveSession() throws {
        let store = try container()
        let context = store.mainContext
        let exercise = WorkoutExercise(title: "Bench Press", subtitle: "Chest", details: "", numberOfSets: 3,
                                       reps: 10, increaseLoadNextTime: false, weight: 30, isDone: true)
        context.insert(exercise)
        let now = Date.now
        let first = ExerciseCompletion(id: "first", completedAt: now, exercise: exercise)
        let second = ExerciseCompletion(id: "second", completedAt: now, exercise: exercise)
        let session = ExerciseSession(exercise: exercise, startedAt: now)
        context.insert(first)
        context.insert(second)
        context.insert(session)
        try context.save()

        try ExerciseHistory.delete([second], in: context)

        let reloaded = ModelContext(store)
        let history = try reloaded.fetch(FetchDescriptor<ExerciseCompletion>())
        XCTAssertEqual(history.map(\.id), ["first"])
        let remainingExercise = try XCTUnwrap(try reloaded.fetch(FetchDescriptor<WorkoutExercise>()).first)
        XCTAssertTrue(remainingExercise.isDone)
        XCTAssertEqual(remainingExercise.completions.map(\.id), ["first"])
        XCTAssertEqual(remainingExercise.weight, 30)
        let remainingSession = try XCTUnwrap(try reloaded.fetch(FetchDescriptor<ExerciseSession>()).first)
        XCTAssertEqual(remainingSession.id, session.id)
        XCTAssertEqual(remainingSession.exercise?.stableID, exercise.stableID)
        XCTAssertEqual(WeeklySummary(completions: history, date: now).total, 1)
        let backup = try JSONSerialization.jsonObject(with: DataBackup.export(from: reloaded, includeHistory: true)) as? [String: Any]
        let exportedHistory = try XCTUnwrap(backup?["history"] as? [[String: Any]])
        XCTAssertEqual(exportedHistory.count, 1)
        XCTAssertEqual(exportedHistory.first?["id"] as? String, "first")
    }

    func testDeletingMultipleEntriesIncludingDeletedExerciseLeavesEmptyHistory() throws {
        let store = try container()
        let context = store.mainContext
        let exercise = WorkoutExercise(title: "Squat", subtitle: "", details: "", numberOfSets: 3,
                                       reps: 8, increaseLoadNextTime: false, weight: 40)
        context.insert(exercise)
        let entries = [ExerciseCompletion(id: "linked", completedAt: .now, exercise: exercise),
                       ExerciseCompletion(id: "orphan", completedAt: .now, exercise: nil)]
        for entry in entries { context.insert(entry) }
        try context.save()

        try ExerciseHistory.delete(entries, in: context)

        let reloaded = ModelContext(store)
        XCTAssertEqual(try reloaded.fetchCount(FetchDescriptor<ExerciseCompletion>()), 0)
        XCTAssertEqual(try reloaded.fetchCount(FetchDescriptor<WorkoutExercise>()), 1)
        XCTAssertTrue(exercise.completions.isEmpty)
        XCTAssertFalse(exercise.isDone)
    }

    func testHistoryRendersAndUpdatesToEmptyAfterDeletion() async throws {
        let store = try container()
        let context = store.mainContext
        let exercise = WorkoutExercise(title: "Bench Press", subtitle: "", details: "", numberOfSets: 3,
                                       reps: 8, increaseLoadNextTime: false, weight: 40)
        context.insert(exercise)
        let now = Date.now
        let entries = [ExerciseCompletion(id: "latest", completedAt: now, exercise: exercise),
                       ExerciseCompletion(id: "previous", completedAt: now.addingTimeInterval(-86_400), exercise: exercise),
                       ExerciseCompletion(id: "orphan", completedAt: now.addingTimeInterval(-172_800), exercise: nil)]
        for entry in entries { context.insert(entry) }
        try context.save()

        let root = UIHostingController(rootView: NavigationStack {
            ExerciseHistoryView()
        }.modelContainer(store))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.overrideUserInterfaceStyle = .light
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        func snapshot(_ name: String) throws {
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-history-\(name).png"))
        }

        try await Task.sleep(for: .milliseconds(500))
        try snapshot("populated")
        window.overrideUserInterfaceStyle = .dark
        try await Task.sleep(for: .milliseconds(200))
        try snapshot("dark")
        try ExerciseHistory.delete(entries, in: context)
        try await Task.sleep(for: .milliseconds(500))
        try snapshot("empty")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 0)
    }
}
