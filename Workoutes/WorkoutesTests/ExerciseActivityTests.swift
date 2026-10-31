import ActivityKit
import SwiftData
import XCTest
import SwiftUI
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
        XCTAssertEqual(state.exerciseID, exercise.stableID)
        XCTAssertNotNil(UUID(uuidString: state.exerciseID))
        XCTAssertLessThan(try JSONEncoder().encode(state).count, 4_096)
        exercise.weight = .infinity
        XCTAssertEqual(exercise.activityContent.weight, 0)
    }

    func testTagIconsStayAlignedWithColorsAndFitTheActivityPayload() throws {
        let container = try makeContainer()
        let item = exercise(String(repeating: "💪", count: 5_000))
        item.subtitle = String(repeating: "💪", count: 5_000)
        item.details = String(repeating: "💪", count: 5_000)
        container.mainContext.insert(item)
        for index in 0..<20 {
            let tag = Tag(name: "Tag \(index)", colorHex: String(format: "%06X", index + 1),
                          iconName: index.isMultiple(of: 3) ? MuscleIcon.chest.rawValue
                            : index.isMultiple(of: 2) ? "future-icon" : nil)
            container.mainContext.insert(tag)
            item.tags.append(tag)
        }
        try container.mainContext.save()

        let state = item.activityContent
        XCTAssertEqual(state.tagColors, item.tags.prefix(12).map(\.colorHex))
        XCTAssertEqual(state.tagIconNames, item.tags.prefix(12).map { $0.muscleIcon?.rawValue })
        XCTAssertEqual(state.tagIconNames?.count, 12)
        let data = try JSONEncoder().encode(state)
        XCTAssertLessThan(data.count, 4_096)
        XCTAssertEqual(try JSONDecoder().decode(ExerciseActivityAttributes.ContentState.self, from: data), state)

        item.tags[0].iconName = MuscleIcon.back.rawValue
        XCTAssertNotEqual(item.activityContent, state, "Editing a tag icon must trigger a Live Activity update")
        XCTAssertEqual(item.activityContent.tagIconNames?.first, MuscleIcon.back.rawValue)
    }

    func testLiveActivityExtensionContainsTheSharedMuscleAssets() throws {
        let plugins = try XCTUnwrap(Bundle.main.builtInPlugInsURL)
        let url = plugins.appendingPathComponent("WorkoutesLiveActivity.appex")
        let widget = try XCTUnwrap(Bundle(url: url))
        for icon in MuscleIcon.allCases {
            XCTAssertNotNil(UIImage(named: icon.baseAsset, in: widget, compatibleWith: nil), icon.rawValue)
            XCTAssertNotNil(UIImage(named: icon.highlightAsset, in: widget, compatibleWith: nil), icon.rawValue)
        }
    }

    func testThreeStateControlStartsCompletesAndResetsExercise() async throws {
        let container = try makeContainer()
        let item = exercise("Three State Exercise")
        container.mainContext.insert(item)
        var now = Date.now
        let controller = ExerciseActivityController(context: container.mainContext, now: { now })
        controller.advanceState(item, context: container.mainContext)
        await controller.waitForPendingUpdates()
        XCTAssertNil(controller.errorMessage)
        XCTAssertTrue(controller.isActive(item))
        XCTAssertFalse(item.isDone)
        let activity = try XCTUnwrap(Activity<ExerciseActivityAttributes>.activities.first {
            $0.content.state.exerciseID == item.activityID
        })

        now = now.addingTimeInterval(11)
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

    func testStandaloneExerciseRequestsActivityBeforeReturningFromTap() async throws {
        let container = try makeContainer()
        let item = exercise("Immediate Lock Screen Activity")
        container.mainContext.insert(item)
        let controller = ExerciseActivityController(context: container.mainContext)

        controller.toggle(item, context: container.mainContext)

        // No await/yield: the user can lock the phone as soon as the tap returns.
        XCTAssertTrue(controller.isActive(item))
        XCTAssertNil(controller.training)
        XCTAssertTrue(Activity<ExerciseActivityAttributes>.activities.contains {
            $0.content.state.exerciseID == item.activityID && $0.activityState == .active
        })
        await controller.waitForPendingUpdates()
        controller.toggle(item, context: container.mainContext)
        await controller.waitForPendingUpdates()
    }

    func testOutdatedQueryCannotCancelPersistedActiveExercise() async throws {
        let container = try makeContainer()
        let item = exercise("Recently Inserted Exercise")
        container.mainContext.insert(item)
        let controller = ExerciseActivityController(context: container.mainContext, liveActivitiesEnabled: false)
        controller.toggle(item, context: container.mainContext)
        await controller.waitForPendingUpdates()

        // SwiftUI can still have the query from before the insert.
        controller.synchronize(exercises: [])
        await controller.waitForPendingUpdates()
        XCTAssertTrue(controller.isActive(item))
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<ExerciseSession>()), 1)

        container.mainContext.delete(item)
        try container.mainContext.save()
        controller.synchronize(exercises: [])
        await controller.waitForPendingUpdates()
        XCTAssertNil(controller.activeExerciseID, "An actual deletion still cancels the activity")
    }

    func testQueuedSynchronizationKeepsItsModelContainerAlive() async throws {
        var container: ModelContainer? = try makeContainer()
        weak var retainedContainer = container
        let controller = ExerciseActivityController(context: container?.mainContext, liveActivitiesEnabled: false)
        controller.synchronize(exercises: [])
        container = nil
        XCTAssertNotNil(retainedContainer)
        await controller.waitForPendingUpdates()
        XCTAssertNil(controller.errorMessage)
    }

    func testLiveActivityLifecycle() async throws {
        XCTAssertTrue(ActivityAuthorizationInfo().areActivitiesEnabled, "The test device must allow Live Activities")
        let container = try makeContainer()
        let first = exercise("Bench Press")
        let second = exercise("Squat")
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        try container.mainContext.save()
        let controller = ExerciseActivityController(context: container.mainContext)
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
        let tag = Tag(name: "Chest", colorHex: "FF8800", iconName: MuscleIcon.chest.rawValue)
        container.mainContext.insert(tag)
        first.tags = [tag]
        controller.synchronize(exercises: [first, second])
        await controller.waitForPendingUpdates()
        try await waitForContent(controller.content(for: first), in: initial)
        XCTAssertEqual(initial.content.state.tagIconNames, [MuscleIcon.chest.rawValue])

        tag.iconName = MuscleIcon.back.rawValue
        controller.synchronize(exercises: [first, second])
        await controller.waitForPendingUpdates()
        try await waitForContent(controller.content(for: first), in: initial)
        XCTAssertEqual(initial.content.state.tagIconNames, [MuscleIcon.back.rawValue])

        // Switching updates the same card instead of leaving a second activity behind.
        second.isDone = true
        controller.toggle(second, context: container.mainContext)
        await controller.waitForPendingUpdates()
        XCTAssertTrue(controller.isActive(second))
        XCTAssertFalse(controller.isActive(first))
        XCTAssertFalse(second.isDone)
        try await waitForContent(controller.content(for: second), in: initial)
        XCTAssertEqual(Activity<ExerciseActivityAttributes>.activities.count, 1)

        let restored = ExerciseActivityController(context: container.mainContext)
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

    func testLiveActivityActionsPersistAndIgnoreOldExerciseButtons() async throws {
        let container = try makeContainer()
        let first = exercise("First")
        let second = exercise("Second")
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        var now = Date.now
        let controller = ExerciseActivityController(context: container.mainContext, now: { now })
        controller.toggle(first, context: container.mainContext)
        await controller.waitForPendingUpdates()
        try await controller.performLiveActivityAction(exerciseID: first.activityID, sessionID: controller.activeSessionID, complete: false,
                                                      context: container.mainContext)
        XCTAssertTrue(first.increaseLoadNextTime)

        controller.toggle(second, context: container.mainContext)
        await controller.waitForPendingUpdates()
        try await controller.performLiveActivityAction(exerciseID: first.activityID, sessionID: controller.activeSessionID, complete: true,
                                                      context: container.mainContext)
        XCTAssertFalse(first.isDone)
        XCTAssertTrue(controller.isActive(second))
        let activity = try XCTUnwrap(Activity<ExerciseActivityAttributes>.activities.first)
        try await waitForContent(controller.content(for: second), in: activity)
        var finalState = controller.content(for: second)
        finalState.status = .done
        finalState.startedAt = nil
        finalState.elapsedSeconds = 11
        now = now.addingTimeInterval(11)
        try await controller.performLiveActivityAction(exerciseID: second.activityID, sessionID: controller.activeSessionID, complete: true,
                                                      context: container.mainContext)
        XCTAssertTrue(second.isDone)
        XCTAssertNil(controller.activeExerciseID)
        try await waitForContent(finalState, in: activity)
        XCTAssertEqual(activity.content.state.status, .done)
    }

    func testOlderActivityPayloadStillDecodes() throws {
        let data = Data("""
        {"exerciseID":"legacy","title":"Squat","subtitle":"","numberOfSets":3,"reps":10,"weight":20,"increaseLoadNextTime":false}
        """.utf8)
        let state = try JSONDecoder().decode(ExerciseActivityAttributes.ContentState.self, from: data)
        XCTAssertNil(state.status)
        XCTAssertNil(state.weightUnitSymbol)
        XCTAssertNil(state.startedAt)
        XCTAssertNil(state.sessionID)
        XCTAssertNil(state.tagIconNames)
        XCTAssertEqual(state.weight, 20)
    }

    func testLiveActivityCardRendersAllControlStates() throws {
        for status in [ExerciseStatus.empty, .playing, .done] {
            let state = ExerciseActivityAttributes.ContentState(
                exerciseID: "preview", title: "Bench Press", subtitle: "Controlled movement",
                numberOfSets: 3, reps: 10, weight: 32.5, increaseLoadNextTime: true,
                details: "Pause at the bottom", tagColors: ["FF8800", "5599FF"],
                tagIconNames: [MuscleIcon.chest.rawValue, nil],
                accentColorHex: "326884", displayedWeight: 32.5, weightUnitSymbol: "kg", status: status,
                sessionID: "preview-session", startedAt: status == .playing ? .now.addingTimeInterval(-125) : nil
            )
            let renderer = ImageRenderer(content: ExerciseActivitySummary(state: state)
                .padding(.horizontal, 16).padding(.vertical, 7).frame(width: 398).background(.black))
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertGreaterThan(image.size.height, 100)
            XCTAssertLessThanOrEqual(image.size.height, 160, "The normal card must fit the Lock Screen's height")
            let data = try XCTUnwrap(image.pngData())
            try data.write(to: URL(fileURLWithPath: "/tmp/workoutes-live-card-\(status.rawValue).png"))
        }
    }

    func testExerciseCardRendersReferenceLayout() throws {
        let container = try makeContainer()
        let item = WorkoutExercise(
            title: "Bench Press",
            subtitle: "Chest · Strength",
            details: "Control the descent",
            numberOfSets: 4,
            reps: 10,
            increaseLoadNextTime: true,
            weight: 60
        )
        let chest = Tag(name: "Chest", colorHex: "FF8800", iconName: MuscleIcon.chest.rawValue)
        let strength = Tag(name: "Strength", colorHex: "5599FF")
        item.tags = [chest, strength]
        container.mainContext.insert(item)

        let renderer = ImageRenderer(
            content: ExerciseCardView(exercise: item)
                .environment(ExerciseActivityController())
                .modelContainer(container)
                .padding(.vertical, 16)
                .frame(width: 398)
                .background(Color(uiColor: .systemGroupedBackground))
        )
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        XCTAssertGreaterThan(image.size.height, 180)
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: URL(fileURLWithPath: "/tmp/workoutes-exercise-card-reference.png"))
    }

    func testExerciseCountMetricsUseExistingBoundsAndUpdateTheirFields() {
        let item = exercise("Bench Press")

        XCTAssertEqual(ExerciseCountMetric.sets.maximum, 20)
        XCTAssertEqual(ExerciseCountMetric.repetitions.maximum, 100)
        XCTAssertEqual(ExerciseCountMetric.sets.label(for: 4), "4 sets")
        XCTAssertEqual(ExerciseCountMetric.repetitions.label(for: 12), "12 reps")

        item[keyPath: ExerciseCountMetric.sets.keyPath] = 4
        item[keyPath: ExerciseCountMetric.repetitions.keyPath] = 12
        XCTAssertEqual(item.numberOfSets, 4)
        XCTAssertEqual(item.reps, 12)
    }

    override func tearDown() async throws {
        for activity in Activity<ExerciseActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
