import SwiftData
import XCTest
@testable import Workoutes

// Matches the shipped schema before identities, sessions and history were introduced.
private enum LegacyCatalog {
    @Model final class Workout {
        var name: String
        var backgroundID: String?
        @Relationship(inverse: \WorkoutExercise.workouts) var exercises: [WorkoutExercise]
        init(name: String, exercises: [WorkoutExercise] = []) { self.name = name; self.exercises = exercises }
    }
    @Model final class Tag {
        var name: String
        var colorHex: String
        @Relationship(inverse: \WorkoutExercise.tags) var exercises: [WorkoutExercise] = []
        init(name: String, colorHex: String) { self.name = name; self.colorHex = colorHex }
    }
    @Model final class WorkoutExercise {
        var title: String
        var subtitle: String
        var details: String
        var numberOfSets: Int
        var reps: Int
        var increaseLoadNextTime: Bool
        var isDone: Bool
        var weight: Double
        var workouts: [Workout] = []
        var tags: [Tag] = []
        init() {
            title = "Legacy Bench"; subtitle = "Chest"; details = "Slow descent"
            numberOfSets = 4; reps = 8; increaseLoadNextTime = true; isDone = true; weight = 60
        }
    }
}

@MainActor
final class PersistenceMigrationTests: XCTestCase {
    private func temporaryStore() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("workoutes-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("catalog.store")
    }

    private func seedLegacyStore(at url: URL) throws {
        let schema = Schema([LegacyCatalog.Workout.self, LegacyCatalog.WorkoutExercise.self, LegacyCatalog.Tag.self])
        let store = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        let context = store.mainContext
        let workout = LegacyCatalog.Workout(name: "Legacy Workout")
        workout.backgroundID = "legacy-background"
        let tag = LegacyCatalog.Tag(name: "Chest", colorHex: "FF8800")
        let item = LegacyCatalog.WorkoutExercise()
        context.insert(workout); context.insert(tag); context.insert(item)
        item.workouts = [workout]; item.tags = [tag]
        let otherWorkout = LegacyCatalog.Workout(name: "Second Workout")
        let otherTag = LegacyCatalog.Tag(name: "Legs", colorHex: "5599FF")
        let other = LegacyCatalog.WorkoutExercise()
        other.title = "Legacy Squat"
        context.insert(otherWorkout); context.insert(otherTag); context.insert(other)
        other.workouts = [otherWorkout]; other.tags = [otherTag]
        try context.save()
    }

    private func openStore(at url: URL) throws -> ModelContainer {
        let schema = Schema([Workout.self, WorkoutExercise.self, Tag.self, ExerciseSession.self, ExerciseCompletion.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
    }

    func testLegacyStoreMigratesWithoutLossOrRetroactiveHistory() throws {
        let url = try temporaryStore()
        try seedLegacyStore(at: url)
        let store = try openStore(at: url)
        let context = store.mainContext
        let items = try context.fetch(FetchDescriptor<WorkoutExercise>())
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Workout>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 2)
        let item = try XCTUnwrap(items.first { $0.title == "Legacy Bench" })
        XCTAssertEqual(item.title, "Legacy Bench")
        XCTAssertEqual(item.weight, 60)
        XCTAssertEqual(item.numberOfSets, 4)
        XCTAssertTrue(item.isDone)
        XCTAssertEqual(item.workouts.first?.name, "Legacy Workout")
        XCTAssertEqual(item.workouts.first?.backgroundID, "legacy-background")
        XCTAssertEqual(item.tags.first?.colorHex, "FF8800")
        XCTAssertNil(item.stableID)
        try CatalogIdentity.backfill(in: context)
        let id = try XCTUnwrap(item.stableID)
        XCTAssertNotNil(UUID(uuidString: id))
        XCTAssertNotNil(item.workouts.first?.stableID)
        XCTAssertNotNil(item.tags.first?.stableID)
        try CatalogIdentity.backfill(in: context)
        XCTAssertEqual(item.stableID, id)
        XCTAssertEqual(Set(items.compactMap(\.stableID)).count, 2)
        let reopened = try openStore(at: url)
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<WorkoutExercise>()).first { $0.title == "Legacy Bench" }?.stableID, id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseSession>()), 0)
    }

    private func startSession(at url: URL, now: Date) async throws -> (String, String) {
        let store = try openStore(at: url)
        let context = store.mainContext
        let item = WorkoutExercise(title: "Persistent", subtitle: "", details: "", numberOfSets: 3, reps: 10,
                                   increaseLoadNextTime: false, weight: 20)
        context.insert(item)
        let controller = ExerciseActivityController(context: context, now: { now }, liveActivitiesEnabled: false)
        controller.toggle(item, context: context)
        await controller.waitForPendingUpdates()
        return (item.activityID, try XCTUnwrap(controller.activeSessionID))
    }

    func testSessionRestoresFromReopenedDiskStoreAndCompletesOnce() async throws {
        let url = try temporaryStore()
        let startedAt = Date.now
        let (exerciseID, sessionID) = try await startSession(at: url, now: startedAt)
        let store = try openStore(at: url)
        let context = store.mainContext
        let finishedAt = startedAt.addingTimeInterval(86_400)
        let restored = ExerciseActivityController(context: context, now: { finishedAt }, liveActivitiesEnabled: false)
        XCTAssertEqual(restored.activeExerciseID, exerciseID)
        XCTAssertEqual(restored.activeSessionID, sessionID)
        XCTAssertEqual(restored.activeStartedAt, startedAt)
        try await restored.performLiveActivityAction(exerciseID: exerciseID, sessionID: sessionID, complete: true, context: context)
        try await restored.performLiveActivityAction(exerciseID: exerciseID, sessionID: sessionID, complete: true, context: context)
        let records = try context.fetch(FetchDescriptor<ExerciseCompletion>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, sessionID)
        XCTAssertEqual(records.first?.completedAt, finishedAt)
        XCTAssertTrue(records.first?.exercise?.isDone == true)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseSession>()), 0)
    }
}
