import SwiftData
import XCTest
@testable import Workoutes

@MainActor
final class SessionControllerTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Workout.self, WorkoutExercise.self, Tag.self,
            SessionTemplate.self, SessionTemplateBlock.self,
            TrainingSession.self, SessionBlockRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeSystem() throws -> (ModelContainer, ExerciseActivityController, SessionController) {
        let container = try makeContainer()
        let exercise = ExerciseActivityController(context: container.mainContext)
        let session = SessionController(
            container: container,
            exerciseController: exercise,
            liveActivitiesEnabled: false,
            notificationsEnabled: false
        )
        return (container, exercise, session)
    }

    private func makeExercise(_ title: String = "Bench Press", sets: Int = 3) -> WorkoutExercise {
        WorkoutExercise(
            title: title, subtitle: "", details: "", numberOfSets: sets,
            reps: 10, increaseLoadNextTime: false, weight: 20
        )
    }

    func testDefaultTemplateAndImmutableSessionSnapshot() throws {
        let (container, _, controller) = try makeSystem()
        let template = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<SessionTemplate>()).first)
        XCTAssertEqual(template.blocks.count, 5)
        XCTAssertEqual(template.blocks.filter { $0.kind == .rest }.count, 2)
        XCTAssertTrue(template.blocks.filter { $0.kind == .exercise }.allSatisfy { $0.restDuration == 60 })

        controller.start()
        XCTAssertNil(controller.errorMessage)
        let snapshot = try XCTUnwrap(controller.activeSession).templateSnapshot.sorted { $0.order < $1.order }
        XCTAssertEqual(snapshot.count, 5)
        let originalName = snapshot[0].name
        template.blocks.sorted { $0.order < $1.order }[0].name = "Changed Later"
        template.blocks.sorted { $0.order < $1.order }[0].restDuration = 120
        XCTAssertEqual(controller.activeSession?.templateSnapshot.sorted { $0.order < $1.order }[0].name, originalName)
        XCTAssertEqual(controller.activeSession?.templateSnapshot.sorted { $0.order < $1.order }[0].duration, 60)
        controller.stopEarly()
    }

    func testActiveExerciseExpandsIntoSetsAndRestsAndCompletesAfterLastSet() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let item = makeExercise(sets: 3)
        container.mainContext.insert(item)
        exerciseController.activate(item, context: container.mainContext)

        controller.start()
        XCTAssertEqual(controller.currentContent?.blockName, "Bench Press · 1/3")
        XCTAssertEqual(controller.activeSession?.blocks.count, 9)
        XCTAssertTrue(exerciseController.isActive(item))

        controller.advance()
        XCTAssertEqual(controller.currentContent?.blockName, "Bench Press · Rest")
        XCTAssertTrue(exerciseController.isActive(item))
        controller.advance()
        XCTAssertEqual(controller.currentContent?.blockName, "Bench Press · 2/3")
        controller.advance()
        XCTAssertEqual(controller.currentContent?.blockName, "Bench Press · Rest")
        controller.advance()
        XCTAssertEqual(controller.currentContent?.blockName, "Bench Press · 3/3")
        controller.advance()

        XCTAssertTrue(item.isDone)
        XCTAssertFalse(item.isActive)
        XCTAssertEqual(controller.currentBlock?.kind, .rest)
        let group = try XCTUnwrap(controller.activeSession).blocks.filter { $0.exerciseGroupID != nil }
        XCTAssertEqual(group.count, 5)
        XCTAssertTrue(group.allSatisfy { $0.startedAt != nil && $0.endedAt != nil })
        controller.stopEarly()
    }

    func testExerciseActivatedDuringGenericExerciseExpandsCurrentBlockWithoutResettingStart() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let item = makeExercise(sets: 2)
        container.mainContext.insert(item)
        controller.start()
        let originalStart = try XCTUnwrap(controller.currentBlock?.startedAt)

        exerciseController.activate(item, context: container.mainContext)
        controller.reconcileActiveExercise()

        XCTAssertEqual(controller.currentContent?.blockName, "Bench Press · 1/2")
        XCTAssertEqual(controller.currentBlock?.startedAt, originalStart)
        XCTAssertEqual(controller.activeSession?.blocks.filter { $0.exerciseGroupID != nil }.count, 3)
        controller.stopEarly()
    }

    func testConfiguredRestBetweenSetsIsCopiedIntoGeneratedRests() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let template = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<SessionTemplate>()).first)
        template.blocks.sorted { $0.order < $1.order }.first { $0.kind == .exercise }?.restDuration = 95
        let item = makeExercise(sets: 2)
        container.mainContext.insert(item)
        exerciseController.activate(item, context: container.mainContext)

        controller.start()

        let generatedRest = try XCTUnwrap(controller.activeSession?.blocks.first { $0.isInterSetRest })
        XCTAssertEqual(generatedRest.plannedRestDuration, 95)
        controller.stopEarly()
    }

    func testExerciseSelectedDuringOriginalRestWaitsForNextExerciseBlock() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let item = makeExercise(sets: 2)
        container.mainContext.insert(item)
        controller.start()
        controller.advance()
        let restID = try XCTUnwrap(controller.currentBlock?.id)

        exerciseController.activate(item, context: container.mainContext)
        controller.reconcileActiveExercise()
        XCTAssertEqual(controller.currentBlock?.id, restID)
        XCTAssertFalse(controller.currentBlock?.isExerciseGroupBlock ?? true)

        controller.advance()
        XCTAssertEqual(controller.currentContent?.blockName, "Bench Press · 1/2")
        XCTAssertTrue(controller.currentBlock?.isExerciseGroupBlock == true)
        controller.stopEarly()
    }

    func testSwitchingExerciseEndsOldGroupAndStartsNewSetOne() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let bench = makeExercise("Bench Press", sets: 3)
        let squat = makeExercise("Squat", sets: 2)
        container.mainContext.insert(bench)
        container.mainContext.insert(squat)
        exerciseController.activate(bench, context: container.mainContext)
        controller.start()
        let oldGroupID = try XCTUnwrap(controller.currentBlock?.exerciseGroupID)
        controller.advance()
        XCTAssertTrue(controller.currentBlock?.isInterSetRest == true)

        exerciseController.activate(squat, context: container.mainContext)
        controller.reconcileActiveExercise()

        XCTAssertTrue(bench.isDone)
        XCTAssertFalse(bench.isActive)
        XCTAssertTrue(exerciseController.isActive(squat))
        XCTAssertEqual(controller.currentContent?.blockName, "Squat · 1/2")
        XCTAssertEqual(controller.currentBlock?.setIndex, 1)
        let oldRecords = try XCTUnwrap(controller.activeSession).blocks.filter { $0.exerciseGroupID == oldGroupID }
        XCTAssertEqual(oldRecords.count, 2)
        XCTAssertTrue(oldRecords.allSatisfy { $0.startedAt != nil && $0.endedAt != nil })
        controller.stopEarly()
    }

    func testManuallyCompletingExerciseDiscardsPendingGroupAndContinuesTemplate() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let item = makeExercise(sets: 4)
        container.mainContext.insert(item)
        exerciseController.activate(item, context: container.mainContext)
        controller.start()
        let groupID = try XCTUnwrap(controller.currentBlock?.exerciseGroupID)

        exerciseController.completeActive(context: container.mainContext)
        controller.reconcileActiveExercise()

        XCTAssertTrue(item.isDone)
        XCTAssertEqual(controller.currentBlock?.kind, .rest)
        XCTAssertFalse(controller.currentBlock?.isInterSetRest ?? true)
        let oldRecords = try XCTUnwrap(controller.activeSession).blocks.filter { $0.exerciseGroupID == groupID }
        XCTAssertEqual(oldRecords.count, 1)
        XCTAssertNotNil(oldRecords.first?.endedAt)
        controller.stopEarly()
    }

    func testRapidDoneThenEmptyStillEndsCurrentGroup() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let item = makeExercise(sets: 3)
        container.mainContext.insert(item)
        exerciseController.activate(item, context: container.mainContext)
        controller.start()

        exerciseController.completeActive(context: container.mainContext)
        exerciseController.advanceState(item, context: container.mainContext)
        controller.reconcileActiveExercise()

        XCTAssertFalse(item.isActive)
        XCTAssertFalse(item.isDone)
        XCTAssertEqual(controller.currentBlock?.kind, .rest)
        XCTAssertFalse(controller.currentBlock?.isInterSetRest ?? true)
        controller.stopEarly()
    }

    func testStoppingEarlyPreservesNotReachedGeneratedBlocksAndClearsExercise() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let item = makeExercise(sets: 3)
        container.mainContext.insert(item)
        exerciseController.activate(item, context: container.mainContext)
        controller.start()
        let session = try XCTUnwrap(controller.activeSession)
        controller.advance()
        XCTAssertTrue(controller.currentBlock?.isInterSetRest == true)

        controller.stopEarly()

        XCTAssertFalse(item.isActive)
        XCTAssertFalse(item.isDone)
        XCTAssertTrue(session.endedEarly)
        let generatedGroup = session.blocks.filter { $0.exerciseGroupID != nil }
        XCTAssertEqual(generatedGroup.count, 5)
        XCTAssertEqual(generatedGroup.filter { $0.startedAt == nil }.count, 3)
    }

    func testSingleSetExerciseCompletesWhenItsOnlySetAdvances() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let item = makeExercise(sets: 1)
        container.mainContext.insert(item)
        exerciseController.activate(item, context: container.mainContext)
        controller.start()
        XCTAssertEqual(controller.currentContent?.blockName, "Bench Press · 1/1")

        controller.advance()

        XCTAssertTrue(item.isDone)
        XCTAssertEqual(controller.currentBlock?.kind, .rest)
        controller.stopEarly()
    }

    func testFrozenExerciseTitleAndSetCountSurviveLaterEdits() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let item = makeExercise(sets: 3)
        container.mainContext.insert(item)
        exerciseController.activate(item, context: container.mainContext)
        controller.start()

        item.title = "Renamed"
        item.numberOfSets = 8
        controller.reconcileActiveExercise()

        XCTAssertEqual(controller.currentContent?.blockName, "Bench Press · 1/3")
        XCTAssertEqual(controller.activeSession?.blocks.filter { $0.exerciseGroupID != nil }.count, 5)
        controller.stopEarly()
    }

    func testDeletedExerciseCanFinishUsingFrozenSnapshot() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let item = makeExercise(sets: 2)
        container.mainContext.insert(item)
        exerciseController.activate(item, context: container.mainContext)
        controller.start()

        container.mainContext.delete(item)
        exerciseController.synchronize(exercises: [])
        controller.reconcileActiveExercise()

        XCTAssertEqual(controller.currentContent?.blockName, "Bench Press · 1/2")
        controller.advance()
        XCTAssertEqual(controller.currentContent?.blockName, "Bench Press · Rest")
        controller.advance()
        XCTAssertEqual(controller.currentContent?.blockName, "Bench Press · 2/2")
        controller.advance()
        XCTAssertEqual(controller.currentBlock?.kind, .rest)
        controller.stopEarly()
    }

    func testInvalidLegacyExerciseRestMigratesToSixtySeconds() throws {
        let (container, _, controller) = try makeSystem()
        let template = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<SessionTemplate>()).first)
        let legacy = SessionTemplateBlock(order: template.blocks.count, name: "Legacy", kind: .exercise, restDuration: 0)
        template.blocks.append(legacy)
        try container.mainContext.save()

        controller.ensureDefaultTemplate()

        XCTAssertEqual(legacy.restDuration, 60)
    }

    func testStaleAdvanceActionIsIgnored() throws {
        let (_, _, controller) = try makeSystem()
        controller.start()
        let original = try XCTUnwrap(controller.currentBlock)
        controller.advance(expectedSessionID: UUID(), expectedBlockID: original.id)
        XCTAssertEqual(controller.currentBlock?.id, original.id)
        controller.advance(expectedSessionID: controller.activeSession?.id, expectedBlockID: original.id)
        XCTAssertNotEqual(controller.currentBlock?.id, original.id)
        controller.stopEarly()
    }

    func testActiveSessionRestoresExpandedTimeline() throws {
        let (container, exerciseController, controller) = try makeSystem()
        let item = makeExercise(sets: 3)
        container.mainContext.insert(item)
        exerciseController.activate(item, context: container.mainContext)
        controller.start()
        let id = try XCTUnwrap(controller.activeSession?.id)
        let blockID = try XCTUnwrap(controller.currentBlock?.id)

        let restored = SessionController(
            container: container,
            exerciseController: exerciseController,
            liveActivitiesEnabled: false,
            notificationsEnabled: false
        )
        XCTAssertTrue(restored.isActive)
        XCTAssertEqual(restored.activeSession?.id, id)
        XCTAssertEqual(restored.currentBlock?.id, blockID)
        XCTAssertEqual(restored.currentContent?.blockName, "Bench Press · 1/3")
        restored.stopEarly()
    }

    func testRestAutomaticallyAdvancesWhileForeground() async throws {
        let (container, _, controller) = try makeSystem()
        let template = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<SessionTemplate>()).first)
        template.blocks.sorted { $0.order < $1.order }.first { $0.kind == .rest }?.restDuration = 0.05
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
