import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class ExerciseActivityTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Workout.self, WorkoutExercise.self, Tag.self,
            SessionTemplate.self, SessionTemplateBlock.self,
            TrainingSession.self, SessionBlockRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func exercise(_ title: String) -> WorkoutExercise {
        WorkoutExercise(title: title, subtitle: "", details: "", numberOfSets: 3,
                        reps: 10, increaseLoadNextTime: false, weight: 20)
    }

    func testThreeStateControlPersistsActiveCompletedAndEmptyStates() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = exercise("Squat")
        context.insert(item)
        try context.save()
        let controller = ExerciseActivityController(context: context)

        controller.advanceState(item, context: context)
        XCTAssertTrue(controller.isActive(item))
        XCTAssertFalse(item.isDone)

        controller.advanceState(item, context: context)
        XCTAssertFalse(item.isActive)
        XCTAssertTrue(item.isDone)
        XCTAssertNil(controller.activeExerciseID)

        controller.advanceState(item, context: context)
        XCTAssertFalse(item.isActive)
        XCTAssertFalse(item.isDone)
    }

    func testActivatingAnotherExerciseClearsThePreviousOneAndRestores() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = exercise("First")
        let second = exercise("Second")
        context.insert(first)
        context.insert(second)
        let controller = ExerciseActivityController(context: context)

        controller.activate(first, context: context)
        controller.activate(second, context: context)
        XCTAssertFalse(first.isActive)
        XCTAssertTrue(second.isActive)

        let restored = ExerciseActivityController(context: context)
        XCTAssertTrue(restored.isActive(second))
        XCTAssertFalse(restored.isActive(first))
    }

    func testOlderExerciseActivityPayloadStillDecodesForMigration() throws {
        let data = Data("""
        {"exerciseID":"legacy","title":"Squat","subtitle":"","numberOfSets":3,"reps":10,"weight":20,"increaseLoadNextTime":false}
        """.utf8)
        let state = try JSONDecoder().decode(ExerciseActivityAttributes.ContentState.self, from: data)
        XCTAssertNil(state.status)
        XCTAssertEqual(state.title, "Squat")
    }

    func testSessionLiveActivityCardRenders() throws {
        let state = SessionActivityAttributes.ContentState(
            sessionID: "session", blockID: "block", blockName: "Bench Press",
            blockKind: .exercise, blockStartedAt: .now.addingTimeInterval(-42),
            sessionStartedAt: .now.addingTimeInterval(-300), restEndsAt: nil,
            currentIndex: 0, totalBlocks: 3, isLastBlock: false, accentColorHex: "326884"
        )
        let renderer = ImageRenderer(content: SessionActivitySummary(state: state)
            .padding(16).frame(width: 398).background(.black))
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        XCTAssertGreaterThan(image.size.height, 80)
    }
}
