import ActivityKit
import SwiftData
import XCTest
@testable import Workoutes

@MainActor
final class ExerciseActivityTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Workout.self, WorkoutExercise.self, Tag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func exercise(_ title: String) -> WorkoutExercise {
        WorkoutExercise(title: title, subtitle: "Controlled movement", details: "",
                        numberOfSets: 3, reps: 10, increaseLoadNextTime: false, weight: 20)
    }

    private func waitForContent(
        _ expected: ExerciseActivityAttributes.ContentState,
        in activity: Activity<ExerciseActivityAttributes>,
        file: StaticString = #filePath, line: UInt = #line
    ) async throws {
        // ActivityKit publishes content asynchronously, even after update() returns.
        for _ in 0..<100 {
            if activity.content.state == expected { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(activity.content.state, expected, file: file, line: line)
    }

    func testContentIsBoundedAndUsesSavedIdentifier() throws {
        let container = try makeContainer()
        let exercise = exercise(String(repeating: "💪", count: 5_000))
        container.mainContext.insert(exercise)
        try container.mainContext.save()
        let state = exercise.activityContent
        XCTAssertEqual(state.title.count, 160)
        XCTAssertEqual(state.exerciseID, exercise.activityID)
        let identifierData = try XCTUnwrap(Data(base64Encoded: state.exerciseID))
        XCTAssertEqual(try JSONDecoder().decode(PersistentIdentifier.self, from: identifierData), exercise.persistentModelID)
        XCTAssertLessThan(try JSONEncoder().encode(state).count, 4_096)
        exercise.weight = .infinity
        XCTAssertEqual(exercise.activityContent.weight, 0)
    }

    func testThreeStateControlStartsCompletesAndResetsExercise() async throws {
        let container = try makeContainer()
        let item = exercise("Three State Exercise")
        container.mainContext.insert(item)
        let controller = ExerciseActivityController()
        controller.advanceState(item, context: container.mainContext)
        await controller.waitForPendingUpdates()
        XCTAssertNil(controller.errorMessage)
        XCTAssertTrue(controller.isActive(item))
        XCTAssertFalse(item.isDone)
        let activity = try XCTUnwrap(Activity<ExerciseActivityAttributes>.activities.first {
            $0.content.state.exerciseID == item.activityID
        })

        controller.advanceState(item, context: container.mainContext)
        await controller.waitForPendingUpdates()
        XCTAssertTrue(item.isDone)
        XCTAssertNil(controller.activeExerciseID)
        for _ in 0..<100 {
            if activity.activityState == .ended || activity.activityState == .dismissed { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(activity.activityState == .ended || activity.activityState == .dismissed)

        controller.advanceState(item, context: container.mainContext)
        XCTAssertFalse(item.isDone)
        XCTAssertNil(controller.activeExerciseID)
    }

    func testLiveActivityLifecycle() async throws {
        XCTAssertTrue(ActivityAuthorizationInfo().areActivitiesEnabled, "The test device must allow Live Activities")
        let container = try makeContainer()
        let first = exercise("Bench Press")
        let second = exercise("Squat")
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        try container.mainContext.save()
        let controller = ExerciseActivityController()
        // The host app has no pre-existing activity on the dedicated test simulator.
        controller.toggle(first, context: container.mainContext)
        await controller.waitForPendingUpdates()
        XCTAssertNil(controller.errorMessage)
        XCTAssertTrue(controller.isActive(first))
        let initial = try XCTUnwrap(Activity<ExerciseActivityAttributes>.activities.first)
        XCTAssertEqual(initial.content.state.title, "Bench Press")

        first.title = "Incline Bench Press"
        first.weight = 32.5
        first.reps = 8
        first.numberOfSets = 4
        first.increaseLoadNextTime = true
        controller.synchronize(exercises: [first, second])
        await controller.waitForPendingUpdates()
        try await waitForContent(first.activityContent, in: initial)

        // Switching updates the same card instead of leaving a second activity behind.
        second.isDone = true
        controller.toggle(second, context: container.mainContext)
        await controller.waitForPendingUpdates()
        XCTAssertTrue(controller.isActive(second))
        XCTAssertFalse(controller.isActive(first))
        XCTAssertFalse(second.isDone)
        try await waitForContent(second.activityContent, in: initial)
        XCTAssertEqual(Activity<ExerciseActivityAttributes>.activities.count, 1)

        let restored = ExerciseActivityController()
        XCTAssertTrue(restored.isActive(second))
        second.isDone = true
        restored.synchronize(exercises: [first, second])
        await restored.waitForPendingUpdates()
        XCTAssertNil(restored.activeExerciseID)
        // ActivityKit reports the final state asynchronously after end() returns.
        for _ in 0..<100 {
            if initial.activityState == .ended || initial.activityState == .dismissed { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(initial.activityState == .ended || initial.activityState == .dismissed)

        restored.toggle(first, context: container.mainContext)
        await restored.waitForPendingUpdates()
        XCTAssertTrue(restored.isActive(first))
        restored.toggle(first, context: container.mainContext)
        await restored.waitForPendingUpdates()
        XCTAssertNil(restored.activeExerciseID)

        restored.toggle(second, context: container.mainContext)
        await restored.waitForPendingUpdates()
        XCTAssertTrue(restored.isActive(second))
        container.mainContext.delete(second)
        restored.synchronize(exercises: [first])
        await restored.waitForPendingUpdates()
        XCTAssertNil(restored.activeExerciseID)
    }

    override func tearDown() async throws {
        for activity in Activity<ExerciseActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
