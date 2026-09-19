import SwiftData
import XCTest
@testable import Workoutes

@MainActor
final class SessionControllerTests: XCTestCase {
    private func makeSystem() throws -> (ModelContainer, ExerciseActivityController, SessionController) {
        let container = try ModelContainer(
            for: Workout.self, WorkoutExercise.self, Tag.self,
            SessionTemplate.self, SessionTemplateBlock.self,
            TrainingSession.self, SessionBlockRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let exercise = ExerciseActivityController(context: container.mainContext)
        let session = SessionController(
            container: container,
            exerciseController: exercise,
            liveActivitiesEnabled: false,
            notificationsEnabled: false
        )
        return (container, exercise, session)
    }

    func testDefaultTemplateAndImmutableSessionSnapshot() throws {
        let (container, _, controller) = try makeSystem()
        let template = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<SessionTemplate>()).first)
        XCTAssertEqual(template.blocks.count, 5)
        XCTAssertEqual(template.blocks.filter { $0.kind == .rest }.count, 2)

        controller.start()
        XCTAssertNil(controller.errorMessage)
        let snapshotNames = try XCTUnwrap(controller.activeSession).blocks
            .sorted { $0.order < $1.order }.map(\.configuredName)
        template.blocks.first?.name = "Changed Later"
        XCTAssertEqual(controller.activeSession?.blocks.sorted { $0.order < $1.order }.map(\.configuredName), snapshotNames)
    }

    func testAdvancingExerciseMarksActiveExerciseDone() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let item = WorkoutExercise(title: "Bench Press", subtitle: "", details: "", numberOfSets: 3,
                                   reps: 10, increaseLoadNextTime: false, weight: 20)
        container.mainContext.insert(item)
        try container.mainContext.save()
        exerciseController.activate(item, context: container.mainContext)
        controller.start()
        XCTAssertNil(controller.errorMessage)

        XCTAssertEqual(controller.currentContent?.blockName, "Bench Press")
        controller.advance()
        XCTAssertTrue(item.isDone)
        XCTAssertFalse(item.isActive)
        XCTAssertEqual(controller.currentBlock?.kind, .rest)
        let first = try XCTUnwrap(controller.activeSession?.blocks.sorted { $0.order < $1.order }.first)
        XCTAssertEqual(first.resolvedName, "Bench Press")
        XCTAssertNotNil(first.measuredDuration)
        controller.stopEarly()
    }

    func testStoppingEarlyDeactivatesWithoutCompletingExerciseAndSavesHistory() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let item = WorkoutExercise(title: "Squat", subtitle: "", details: "", numberOfSets: 3,
                                   reps: 10, increaseLoadNextTime: false, weight: 20)
        container.mainContext.insert(item)
        try container.mainContext.save()
        exerciseController.activate(item, context: container.mainContext)
        controller.start()
        XCTAssertNil(controller.errorMessage)
        let sessionID = controller.activeSession?.id

        controller.stopEarly()
        XCTAssertFalse(item.isActive)
        XCTAssertFalse(item.isDone)
        XCTAssertFalse(controller.isActive)
        let saved = try container.mainContext.fetch(FetchDescriptor<TrainingSession>())
            .first { $0.id == sessionID }
        XCTAssertEqual(saved?.endedEarly, true)
        XCTAssertNotNil(saved?.endedAt)
    }

    func testStaleAdvanceActionIsIgnored() throws {
        let (_, _, controller) = try makeSystem()
        controller.start()
        XCTAssertNil(controller.errorMessage)
        let original = try XCTUnwrap(controller.currentBlock)
        controller.advance(expectedSessionID: UUID(), expectedBlockID: original.id)
        XCTAssertEqual(controller.currentBlock?.id, original.id)
        controller.advance(expectedSessionID: controller.activeSession?.id, expectedBlockID: original.id)
        XCTAssertNotEqual(controller.currentBlock?.id, original.id)
        controller.stopEarly()
    }

    func testActiveSessionRestoresFromDatesAfterControllerRecreation() throws {
        let (container, exerciseController, controller) = try makeSystem()
        controller.start()
        let id = try XCTUnwrap(controller.activeSession?.id)

        let restored = SessionController(
            container: container,
            exerciseController: exerciseController,
            liveActivitiesEnabled: false,
            notificationsEnabled: false
        )
        XCTAssertTrue(restored.isActive)
        XCTAssertEqual(restored.activeSession?.id, id)
        XCTAssertNotNil(restored.currentContent)
    }

    func testRestAutomaticallyAdvancesWhileForeground() async throws {
        let (container, _, controller) = try makeSystem()
        let template = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<SessionTemplate>()).first)
        template.blocks.first { $0.kind == .rest }?.restDuration = 0.05
        try container.mainContext.save()
        controller.start()
        controller.advance()
        XCTAssertEqual(controller.currentBlock?.kind, .rest)
        XCTAssertEqual(controller.currentBlock?.plannedRestDuration ?? 0, 0.05, accuracy: 0.001)

        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(controller.currentBlock?.kind, .exercise)
        XCTAssertEqual(controller.currentBlock?.order, 2)
        controller.stopEarly()
    }
}
