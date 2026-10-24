import ActivityKit
import SwiftData
import XCTest
@testable import Workoutes

@MainActor
final class TrainingLiveActivityTests: XCTestCase {
    @MainActor private struct Fixture {
        let container: ModelContainer
        let phone: PhoneTrainingController
        let activity: ExerciseActivityController
        let first: WorkoutExercise
        let second: WorkoutExercise
        var context: ModelContext { container.mainContext }
    }

    private func fixture() async throws -> Fixture {
        for activity in Activity<ExerciseActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        XCTAssertTrue(ActivityAuthorizationInfo().areActivitiesEnabled)
        let container = try ModelContainer(for: Workout.self, WorkoutExercise.self, Tag.self, ExerciseSession.self, ExerciseCompletion.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let first = WorkoutExercise(title: "Bench Press", subtitle: "", details: "", numberOfSets: 2,
                                    reps: 8, increaseLoadNextTime: false, weight: 40)
        let second = WorkoutExercise(title: "Squat", subtitle: "", details: "", numberOfSets: 3,
                                     reps: 10, increaseLoadNextTime: false, weight: 60)
        container.mainContext.insert(first); container.mainContext.insert(second)
        try container.mainContext.save()
        let store = TrainingStore(url: FileManager.default.temporaryDirectory.appending(path: "TrainingLiveActivityTests/\(UUID().uuidString).json"))
        let phone = PhoneTrainingController(store: store, activate: false)
        let activity = ExerciseActivityController(context: container.mainContext)
        phone.attach(context: container.mainContext, exerciseActivity: activity)
        await activity.waitForPendingUpdates()
        return Fixture(container: container, phone: phone, activity: activity, first: first, second: second)
    }

    private func selection(_ item: WorkoutExercise, sets: Int = 2) throws -> TrainingExercise {
        .init(id: try XCTUnwrap(item.stableID), name: item.title, weightKilograms: item.weight,
              repetitions: item.reps, sets: sets, usesPounds: false)
    }

    private func liveActivity() throws -> Activity<ExerciseActivityAttributes> {
        try XCTUnwrap(Activity<ExerciseActivityAttributes>.activities.first { $0.activityState == .active || $0.activityState == .stale })
    }

    private func waitForContent(_ expected: ExerciseActivityAttributes.ContentState, in activity: Activity<ExerciseActivityAttributes>) async throws {
        for _ in 0..<100 {
            if activity.content.state == expected { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(activity.content.state, expected)
    }

    func testLocalActivitySurvivesTrackerStartAndFinishWithoutAnExerciseSelection() async throws {
        let f = try await fixture()
        f.activity.toggle(f.first, context: f.context)
        await f.activity.waitForPendingUpdates()
        let live = try liveActivity()
        let identity = f.activity.activeSessionID
        var run = try TrainingRun(plan: .daily, at: .now)
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        XCTAssertTrue(f.activity.isActive(f.first))
        XCTAssertEqual(f.activity.activeSessionID, identity)
        XCTAssertEqual(try liveActivity().id, live.id)
        run.finish(effort: nil, at: .now)
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        XCTAssertTrue(f.activity.isActive(f.first))
        XCTAssertEqual(try liveActivity().id, live.id)
        f.activity.toggle(f.first, context: f.context)
        await f.activity.waitForPendingUpdates()
    }

    func testWatchExercisePublishesDuringSeriesRestPauseAndDisconnectionWithoutLocalSession() async throws {
        let f = try await fixture()
        let start = Date.now.addingTimeInterval(-40)
        var run = try TrainingRun(plan: .daily, at: start)
        try run.select(selection(f.first), at: start.addingTimeInterval(5))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        let live = try liveActivity()
        XCTAssertFalse(f.phone.isConnected)
        XCTAssertEqual(f.activity.activeExerciseID, f.first.activityID)
        XCTAssertEqual(try f.context.fetchCount(FetchDescriptor<ExerciseSession>()), 0)
        let startedAt = f.activity.activeStartedAt
        let oldButton = f.activity.activeSessionID
        try run.advance(at: start.addingTimeInterval(30))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        try await waitForContent(f.activity.content(for: f.first), in: live)
        XCTAssertEqual(try liveActivity().id, live.id)
        XCTAssertEqual(f.activity.activeStartedAt, startedAt)
        XCTAssertNotEqual(f.activity.activeSessionID, oldButton)
        run.togglePause(at: .now)
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        XCTAssertEqual(try liveActivity().id, live.id)
        f.activity.restore()
        await f.activity.waitForPendingUpdates()
        XCTAssertEqual(try liveActivity().id, live.id)
        run.finish(effort: nil, at: .now)
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        XCTAssertNil(f.activity.activeExerciseID)
        XCTAssertTrue(live.activityState == .ended || live.activityState == .dismissed)
        XCTAssertEqual(try f.context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 0)
    }

    func testLocalExerciseCanStopWhileTrackerIsWaitingForASelection() async throws {
        let f = try await fixture()
        f.activity.toggle(f.first, context: f.context)
        await f.activity.waitForPendingUpdates()
        let live = try liveActivity()
        let run = try TrainingRun(plan: .daily, at: .now)
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        f.activity.toggle(f.first, context: f.context)
        await f.activity.waitForPendingUpdates()
        XCTAssertNil(f.activity.activeExerciseID)
        XCTAssertNil(f.phone.errorMessage)
        XCTAssertTrue(f.phone.hasActiveSession)
        XCTAssertEqual(f.phone.run?.progress.stage, .choosingExercise)
        XCTAssertTrue(live.activityState == .ended || live.activityState == .dismissed)
    }

    func testWatchSelectionReusesLocalActivityAndCatalogEditsStillRefreshIt() async throws {
        let f = try await fixture()
        f.activity.toggle(f.first, context: f.context)
        await f.activity.waitForPendingUpdates()
        let live = try liveActivity()
        var run = try TrainingRun(plan: .daily, at: .now.addingTimeInterval(-20))
        try run.select(selection(f.second), at: .now.addingTimeInterval(-10))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        try await waitForContent(f.activity.content(for: f.second), in: live)
        XCTAssertEqual(try liveActivity().id, live.id)
        XCTAssertTrue(f.activity.isActive(f.second))
        XCTAssertFalse(f.activity.isActive(f.first))
        XCTAssertEqual(try f.context.fetchCount(FetchDescriptor<ExerciseSession>()), 0)
        XCTAssertEqual(try f.context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 0)
        let tag = Tag(name: "Legs", colorHex: "FF8800", iconName: MuscleIcon.lowerBody.rawValue)
        f.context.insert(tag); f.second.tags = [tag]
        f.second.increaseLoadNextTime = true
        f.second.weight = 100 // The tracked exercise retains its selected training values.
        f.activity.synchronize(exercises: [f.first, f.second])
        await f.activity.waitForPendingUpdates()
        try await waitForContent(f.activity.content(for: f.second), in: live)
        XCTAssertEqual(live.content.state.weight, 60)
        XCTAssertEqual(live.content.state.tagIconNames, [MuscleIcon.lowerBody.rawValue])
        XCTAssertTrue(live.content.state.increaseLoadNextTime)
        run.finish(effort: nil, at: .now)
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        XCTAssertNil(f.activity.activeExerciseID, "A superseded local exercise must not reappear")
    }

    func testQueuedExerciseDoesNotReplaceActivityUntilItsBlockStarts() async throws {
        let f = try await fixture()
        let start = Date.now.addingTimeInterval(-40)
        var run = try TrainingRun(plan: .daily, at: start)
        try run.select(selection(f.first, sets: 1), at: start.addingTimeInterval(5))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        let firstActivity = try liveActivity()
        try run.select(selection(f.second), at: start.addingTimeInterval(10))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        XCTAssertEqual(try liveActivity().content.state.exerciseID, f.first.activityID)
        try run.advance(at: start.addingTimeInterval(30))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        XCTAssertNil(f.activity.activeExerciseID)
        XCTAssertTrue(firstActivity.activityState == .ended || firstActivity.activityState == .dismissed)
        XCTAssertTrue(run.tick(at: start.addingTimeInterval(330)))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        XCTAssertEqual(try liveActivity().content.state.exerciseID, f.second.activityID)
        XCTAssertEqual(try f.context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
        run.finish(effort: nil, at: .now)
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
    }

    func testTrackingActivityRestoresAndIgnoresButtonsFromPreviousSeries() async throws {
        let f = try await fixture()
        let start = Date.now.addingTimeInterval(-40)
        var run = try TrainingRun(plan: .daily, at: start)
        try run.select(selection(f.first), at: start.addingTimeInterval(5))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        let live = try liveActivity()
        let oldButton = f.activity.activeSessionID
        let restored = ExerciseActivityController(context: f.context)
        f.phone.attach(context: f.context, exerciseActivity: restored)
        restored.restore()
        await restored.waitForPendingUpdates()
        XCTAssertEqual(restored.activeSessionID, oldButton)
        XCTAssertEqual(try liveActivity().id, live.id)
        try run.advance(at: start.addingTimeInterval(30))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await restored.waitForPendingUpdates()
        try await restored.performLiveActivityAction(exerciseID: f.first.activityID, sessionID: oldButton,
                                                    complete: true, context: f.context)
        XCTAssertNil(f.phone.errorMessage)
        try await restored.performLiveActivityAction(exerciseID: f.first.activityID, sessionID: restored.activeSessionID,
                                                    complete: false, context: f.context)
        XCTAssertTrue(f.first.increaseLoadNextTime)
        try await restored.performLiveActivityAction(exerciseID: f.first.activityID, sessionID: restored.activeSessionID,
                                                    complete: true, context: f.context)
        XCTAssertNotNil(f.phone.errorMessage, "An offline watch action must use the workout command channel")
        XCTAssertEqual(try f.context.fetchCount(FetchDescriptor<ExerciseSession>()), 0)
        XCTAssertEqual(try f.context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 0)
        run.finish(effort: nil, at: .now)
        f.phone.receive(.init(kind: .snapshot, run: run))
        await restored.waitForPendingUpdates()
    }
}
