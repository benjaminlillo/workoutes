import ActivityKit
import SwiftData
import SwiftUI
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
        // Not activating a connection doesn't disable WCSession.default, which
        // can remain reachable from another controller in the test host.
        let phone = PhoneTrainingController(store: store, activate: false, commandSender: { envelope in
            XCTAssertEqual(envelope.command?.action, .advance)
            throw TrainingFailure.notConnected
        })
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

    func testQueuedExerciseReusesActivityDuringBlockRestAndWhenItsBlockStarts() async throws {
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
        try await waitForContent(f.activity.content(for: f.second), in: firstActivity)
        XCTAssertEqual(try liveActivity().id, firstActivity.id)
        XCTAssertEqual(firstActivity.content.state.exerciseID, f.second.activityID)
        XCTAssertEqual(firstActivity.content.state.isQueued, true)
        XCTAssertEqual(firstActivity.content.state.status, .empty)
        XCTAssertNil(firstActivity.content.state.startedAt)
        XCTAssertNil(firstActivity.content.state.sessionID)
        XCTAssertTrue(run.tick(at: start.addingTimeInterval(330)))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        try await waitForContent(f.activity.content(for: f.second), in: firstActivity)
        XCTAssertEqual(try liveActivity().id, firstActivity.id)
        XCTAssertEqual(firstActivity.content.state.exerciseID, f.second.activityID)
        XCTAssertNotEqual(firstActivity.content.state.isQueued, true)
        XCTAssertEqual(firstActivity.content.state.status, .playing)
        XCTAssertEqual(firstActivity.content.state.startedAt, start.addingTimeInterval(330))
        XCTAssertEqual(try f.context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
        run.finish(effort: nil, at: .now)
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
    }

    func testQueueingDuringRestCreatesActivityWithoutStartingAnExerciseOrAcceptingStop() async throws {
        let f = try await fixture()
        let start = Date.now.addingTimeInterval(-40)
        var run = try TrainingRun(plan: .daily, at: start)
        try run.select(selection(f.first, sets: 1), at: start.addingTimeInterval(5))
        try run.advance(at: start.addingTimeInterval(20))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        XCTAssertFalse(Activity<ExerciseActivityAttributes>.activities.contains { $0.activityState == .active })
        try run.select(selection(f.second), at: start.addingTimeInterval(30))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        let live = try liveActivity()
        XCTAssertEqual(live.content.state.isQueued, true)
        XCTAssertEqual(live.content.state.exerciseID, f.second.activityID)
        XCTAssertFalse(f.activity.isActive(f.second))
        XCTAssertTrue(f.activity.isQueued(f.second))
        XCTAssertNil(f.activity.activeSessionID)
        XCTAssertEqual(try f.context.fetchCount(FetchDescriptor<ExerciseSession>()), 0)
        XCTAssertEqual(try f.context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
        try await f.activity.performLiveActivityAction(exerciseID: f.second.activityID, sessionID: "old-button",
                                                     complete: true, context: f.context)
        XCTAssertNil(f.phone.errorMessage)
        XCTAssertFalse(f.second.isDone)
        XCTAssertEqual(f.phone.run?.progress.stage, .blockRest)
        run.finish(effort: nil, at: .now)
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        XCTAssertTrue(live.activityState == .ended || live.activityState == .dismissed)
    }

    func testQueuedActivitySupportsReplacementRestoreAndRemovalIncludingCompletedCatalogExercise() async throws {
        let f = try await fixture()
        let start = Date.now.addingTimeInterval(-40)
        var run = try TrainingRun(plan: .daily, at: start)
        try run.select(selection(f.first, sets: 1), at: start.addingTimeInterval(5))
        try run.advance(at: start.addingTimeInterval(20))
        try run.select(selection(f.second), at: start.addingTimeInterval(30))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        let live = try liveActivity()
        f.second.weight = 100
        f.activity.synchronize(exercises: [f.first, f.second])
        await f.activity.waitForPendingUpdates()
        try await waitForContent(f.activity.content(for: f.second), in: live)
        XCTAssertEqual(live.content.state.weight, 60, "Queue uses the selected exercise snapshot")
        XCTAssertTrue(f.first.isDone)
        try run.select(selection(f.first), at: start.addingTimeInterval(35))
        f.phone.receive(.init(kind: .snapshot, run: run))
        await f.activity.waitForPendingUpdates()
        try await waitForContent(f.activity.content(for: f.first), in: live)
        XCTAssertEqual(try liveActivity().id, live.id)
        XCTAssertEqual(live.content.state.isQueued, true)
        XCTAssertEqual(live.content.state.status, .empty)

        let restored = ExerciseActivityController(context: f.context)
        f.phone.attach(context: f.context, exerciseActivity: restored)
        restored.restore()
        await restored.waitForPendingUpdates()
        XCTAssertEqual(try liveActivity().id, live.id)
        XCTAssertNil(restored.activeExerciseID)
        XCTAssertEqual(restored.content(for: f.first).isQueued, true)
        run.togglePause(at: .now)
        f.phone.receive(.init(kind: .snapshot, run: run))
        await restored.waitForPendingUpdates()
        XCTAssertEqual(try liveActivity().id, live.id)
        run.togglePause(at: .now)
        try run.clearQueuedExercise(at: .now)
        f.phone.receive(.init(kind: .snapshot, run: run))
        await restored.waitForPendingUpdates()
        XCTAssertTrue(live.activityState == .ended || live.activityState == .dismissed)
        XCTAssertEqual(try f.context.fetchCount(FetchDescriptor<ExerciseSession>()), 0)
        XCTAssertEqual(try f.context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
    }

    func testQueuedActivitySummaryRendersForVisualInspection() throws {
        let state = ExerciseActivityAttributes.ContentState(
            exerciseID: "preview", title: "Press de banca con mancuernas", subtitle: "Pecho",
            numberOfSets: 3, reps: 10, weight: 24, increaseLoadNextTime: false,
            accentColorHex: "B784E8", status: .empty, isQueued: true)
        let renderer = ImageRenderer(content: ExerciseActivitySummary(state: state).padding(16).frame(width: 400).background(.black))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-queued-live-activity.png"))
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
        XCTAssertNotNil(restored.activeSessionID)
        XCTAssertTrue(restored.isActive(f.first))
        XCTAssertFalse(f.first.isDone)
        XCTAssertEqual(f.phone.run?.canAdvance, true)
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
