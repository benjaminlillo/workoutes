import SwiftData
import SwiftUI
import XCTest
import HealthKit
@testable import Workoutes

@MainActor
final class TrainingTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_790_000_000)
    private func date(_ seconds: Double) -> Date { origin.addingTimeInterval(seconds) }
    private func exercise(sets: Int = 3, id: String = "bench") -> TrainingExercise {
        .init(id: id, name: "Bench Press", weightKilograms: 40, repetitions: 8, sets: sets, usesPounds: false)
    }
    private func makeRun(rest: Int = 120, sets: Int = 3) throws -> TrainingRun {
        var run = try TrainingRun(plan: .init(blocks: [.init(kind: .exercise, seconds: rest), .init(kind: .rest, seconds: 300),
                                                      .init(kind: .exercise, seconds: 120)]), at: origin)
        try run.select(exercise(sets: sets), at: date(10))
        return run
    }
    private func store() -> TrainingStore {
        TrainingStore(url: FileManager.default.temporaryDirectory.appending(path: "TrainingTests/\(UUID().uuidString).json"))
    }
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Workout.self, WorkoutExercise.self, Tag.self, ExerciseSession.self, ExerciseCompletion.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testHealthAuthorizationRequiresAnExplicitWorkoutWriteGrant() throws {
        XCTAssertNoThrow(try TrainingHealthAuthorization.check(.sharingAuthorized))
        XCTAssertThrowsError(try TrainingHealthAuthorization.check(.notDetermined)) { error in
            XCTAssertTrue(error.localizedDescription.contains("hasn't been completed"))
        }
        XCTAssertThrowsError(try TrainingHealthAuthorization.check(.sharingDenied)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Allow Workoutes to Write"))
        }
        XCTAssertTrue(TrainingHealthAuthorization.writeTypes.contains(HKObjectType.workoutType()))
        XCTAssertFalse(TrainingHealthAuthorization.writeTypes.contains(HKQuantityType(.heartRate)))
        XCTAssertTrue(TrainingHealthAuthorization.readTypes.contains(HKQuantityType(.heartRate)))
    }

    func testSimulatorPreviewRestoresProgressAndKeepsItsLocalOnlyIdentityInHistory() throws {
        var preview = try makeRun(rest: 15, sets: 2)
        preview.isSimulatorPreview = true
        preview.healthSaveSkipped = true
        try preview.advance(at: date(40))
        let disk = store()
        var archive = TrainingArchive(); archive.current = preview
        try disk.write(archive)
        var restored = try XCTUnwrap(disk.read().current)
        XCTAssertTrue(restored.tick(at: date(55)))
        XCTAssertEqual(restored.seriesNumber, 2)
        try restored.advance(at: date(70))
        restored.finish(effort: 5, at: date(80))
        let phone = PhoneTrainingController(store: store(), activate: false)
        phone.receive(.init(kind: .snapshot, run: restored))
        let saved = try XCTUnwrap(phone.history.first)
        XCTAssertEqual(saved.isSimulatorPreview, true)
        XCTAssertEqual(saved.healthSaveSkipped, true)
        XCTAssertEqual(saved.progress.results.first?.sets.count, 2)
        XCTAssertNil(saved.healthWorkoutID)
        XCTAssertNil(saved.metrics.heartRate)
        XCTAssertNil(saved.metrics.activeCalories)
        // Archives created before preview support remain readable.
        let original = try JSONEncoder().encode(try makeRun())
        XCTAssertNil(try JSONDecoder().decode(TrainingRun.self, from: original).isSimulatorPreview)
    }

    func testDefaultStructureHasFourGenericBlocksAndThreeFiveMinuteRests() throws {
        let plan = TrainingPlan.daily
        XCTAssertTrue(plan.isValid)
        XCTAssertEqual(plan.exerciseCount, 4)
        XCTAssertEqual(plan.blocks.map(\.kind), [.exercise, .rest, .exercise, .rest, .exercise, .rest, .exercise])
        XCTAssertEqual(plan.blocks.filter { $0.kind == .exercise }.map(\.seconds), [120, 120, 120, 120])
        XCTAssertEqual(plan.blocks.filter { $0.kind == .rest }.map(\.seconds), [300, 300, 300])
        let run = try TrainingRun(plan: plan, at: origin)
        XCTAssertEqual(run.progress.stage, .choosingExercise)
        XCTAssertTrue(run.progress.results.isEmpty)
        XCTAssertNil(run.currentResult)
    }

    func testInvalidStructuresAndExercisesAreRejected() throws {
        let duplicate = TrainingBlock(kind: .exercise, seconds: 120)
        for plan in [TrainingPlan(blocks: []), .init(blocks: [.init(kind: .rest, seconds: 10)]),
                     .init(blocks: [duplicate, duplicate]), .init(blocks: [.init(kind: .exercise, seconds: -1)]),
                     .init(blocks: [.init(kind: .exercise, seconds: 0), .init(kind: .rest, seconds: 0)])] {
            XCTAssertThrowsError(try TrainingRun(plan: plan, at: origin))
        }
        var run = try TrainingRun(plan: .daily, at: origin)
        XCTAssertThrowsError(try run.select(exercise(sets: 0), at: date(10)))
        var invalid = exercise(); invalid.weightKilograms = .infinity
        XCTAssertThrowsError(try run.select(invalid, at: date(10)))
        XCTAssertTrue(run.canSelectExercise)
    }

    func testLegacyArchiveKeepsEffortEnabledAndPreservesHistoricalRatings() throws {
        var finished = try makeRun()
        finished.finish(effort: 7, at: date(80))
        var archive = TrainingArchive()
        archive.current = try makeRun()
        archive.history = [finished]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(archive)) as? [String: Any])
        func legacyPlan(_ value: Any?) throws -> [String: Any] {
            var plan = try XCTUnwrap(value as? [String: Any])
            plan.removeValue(forKey: "asksForEffortRating")
            return plan
        }
        json["plan"] = try legacyPlan(json["plan"])
        var current = try XCTUnwrap(json["current"] as? [String: Any])
        current["plan"] = try legacyPlan(current["plan"])
        json["current"] = current
        var history = try XCTUnwrap(json["history"] as? [[String: Any]])
        history[0]["plan"] = try legacyPlan(history[0]["plan"])
        json["history"] = history

        let restored = try JSONDecoder().decode(TrainingArchive.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(restored.plan.asksForEffortRating)
        XCTAssertEqual(restored.current, archive.current)
        XCTAssertEqual(restored.history, archive.history)
        XCTAssertEqual(restored.history.first?.effort, 7)
    }

    func testEffortPreferencePersistsAndTravelsWithTheWatchStartPlan() throws {
        let disk = store()
        let phone = PhoneTrainingController(store: disk, activate: false)
        var plan = phone.plan
        XCTAssertTrue(plan.asksForEffortRating)
        plan.asksForEffortRating = false
        try phone.savePlan(plan)
        let restored = PhoneTrainingController(store: disk, activate: false)
        XCTAssertEqual(restored.plan, plan)

        let message = TrainingEnvelope(kind: .command, command: .init(action: .start, plan: restored.plan))
        let decoded = try JSONDecoder().decode(TrainingEnvelope.self, from: JSONEncoder().encode(message))
        var run = try TrainingRun(plan: XCTUnwrap(decoded.command?.plan), at: origin)
        run.finish(effort: nil, at: date(80))
        restored.receive(.init(kind: .snapshot, run: run))
        let relaunched = PhoneTrainingController(store: disk, activate: false)
        XCTAssertEqual(relaunched.history.first?.plan.asksForEffortRating, false)
        XCTAssertNil(relaunched.history.first?.effort)
    }

    func testDisabledEffortDiscardsEvenASuppliedRatingAndKeepsOtherResults() throws {
        var plan = TrainingPlan.daily
        plan.asksForEffortRating = false
        var run = try TrainingRun(plan: plan, at: origin)
        try run.select(exercise(sets: 1), at: date(10))
        try run.advance(at: date(40))
        run.metrics.activeCalories = 20
        run.finish(effort: 8, at: date(80))
        XCTAssertFalse(run.isActive)
        XCTAssertNil(run.effort)
        XCTAssertFalse(run.effortSaved)
        XCTAssertEqual(run.elapsed(at: date(100)), 80)
        XCTAssertEqual(run.metrics.activeCalories, 20)
        XCTAssertEqual(run.progress.results.first?.sets.count, 1)
        XCTAssertEqual(run.progress.results.first?.isComplete, true)
    }

    func testChangingEffortTemplateOnlyAffectsNewSessions() throws {
        var plan = TrainingPlan.daily
        var existing = try TrainingRun(plan: plan, at: origin)
        plan.asksForEffortRating = false
        var next = try TrainingRun(plan: plan, at: date(100))
        existing.finish(effort: 6, at: date(80))
        next.finish(effort: 6, at: date(180))
        XCTAssertEqual(existing.effort, 6)
        XCTAssertNil(next.effort)
        plan.asksForEffortRating = true
        let data = try JSONEncoder().encode(plan)
        XCTAssertTrue(try JSONDecoder().decode(TrainingPlan.self, from: data).asksForEffortRating)
    }

    func testSelectionStartsFirstSeriesAndUsesExerciseSnapshot() throws {
        var run = try TrainingRun(plan: .daily, at: origin)
        var selected = exercise(sets: 4)
        try run.select(selected, at: date(40))
        selected.name = "Changed Later"; selected.sets = 2
        XCTAssertEqual(run.phaseElapsed(at: date(45)), 5)
        XCTAssertEqual(run.elapsed(at: date(45)), 45)
        XCTAssertEqual(run.currentResult?.exercise.sets, 4)
        XCTAssertEqual(run.currentResult?.exercise.name, "Bench Press")
        XCTAssertEqual(run.seriesNumber, 1)
        try run.select(selected, at: date(46))
        XCTAssertEqual(run.currentResult?.exercise.name, "Bench Press")
        XCTAssertEqual(run.currentResult?.exercise.sets, 4)
        XCTAssertEqual(run.queuedExercise?.name, "Changed Later")
        XCTAssertEqual(run.queuedExercise?.sets, 2)
        XCTAssertEqual(run.phaseElapsed(at: date(46)), 6)
    }

    func testQueuedExerciseWaitsForRestDeadlineAndStartsAtTheCorrectTime() throws {
        var run = try makeRun(sets: 1)
        try run.advance(at: date(40))
        let next = exercise(sets: 4, id: "squat")
        try run.select(next, at: date(100))
        XCTAssertEqual(run.progress.stage, .blockRest)
        XCTAssertEqual(run.queuedExercise, next)
        XCTAssertEqual(run.queuedExerciseNumber, 2)
        XCTAssertEqual(run.progress.results.count, 1)
        XCTAssertNil(run.currentResult)
        XCTAssertEqual(run.remaining(at: date(100)), 240)
        XCTAssertFalse(run.tick(at: date(339)))
        XCTAssertTrue(run.tick(at: date(350)))
        XCTAssertEqual(run.progress.stage, .series)
        XCTAssertEqual(run.currentResult?.exercise, next)
        XCTAssertEqual(run.seriesNumber, 1)
        XCTAssertEqual(run.phaseElapsed(at: date(350)), 10)
        XCTAssertEqual(run.elapsed(at: date(350)), 350)
        XCTAssertNil(run.queuedExercise)
        XCTAssertEqual(run.progress.results.count, 2)
    }

    func testQueueDuringSeriesAndSeriesRestDoesNotReplaceTheCurrentExercise() throws {
        var run = try makeRun(sets: 2)
        try run.select(exercise(id: "squat"), at: date(20))
        XCTAssertEqual(run.currentResult?.exercise.id, "bench")
        XCTAssertEqual(run.phaseElapsed(at: date(20)), 10)
        try run.advance(at: date(40))
        try run.select(exercise(sets: 4, id: "press"), at: date(50))
        XCTAssertEqual(run.progress.stage, .seriesRest)
        XCTAssertEqual(run.currentResult?.sets.count, 1)
        XCTAssertEqual(run.queuedExercise?.id, "press")
        XCTAssertEqual(run.remaining(at: date(50)), 110)
        XCTAssertTrue(run.tick(at: date(160)))
        XCTAssertEqual(run.seriesNumber, 2)
        try run.advance(at: date(180))
        XCTAssertEqual(run.progress.stage, .blockRest)
        XCTAssertEqual(run.queuedExercise?.id, "press")
        try run.advance(at: date(200))
        XCTAssertEqual(run.currentResult?.exercise.id, "press")
        XCTAssertEqual(run.currentResult?.exercise.sets, 4)
        XCTAssertEqual(run.seriesNumber, 1)
        XCTAssertEqual(run.phaseElapsed(at: date(200)), 0)
        XCTAssertNil(run.queuedExercise)
    }

    func testRemovingAndUndoingQueueEditsPreservesRestClockIncludingPauses() throws {
        var run = try makeRun(sets: 1)
        try run.advance(at: date(40))
        try run.select(exercise(id: "squat"), at: date(100))
        try run.clearQueuedExercise(at: date(110))
        XCTAssertNil(run.queuedExercise)
        try run.undoTransition(at: date(120))
        XCTAssertEqual(run.queuedExercise?.id, "squat")
        XCTAssertEqual(run.remaining(at: date(120)), 220)
        try run.clearQueuedExercise(at: date(130))
        run.togglePause(at: date(140))
        run.togglePause(at: date(200))
        try run.undoTransition(at: date(210))
        XCTAssertEqual(run.queuedExercise?.id, "squat")
        XCTAssertEqual(run.remaining(at: date(210)), 190)
        XCTAssertEqual(run.elapsed(at: date(210)), 150)
    }

    func testUndoingQueuedSelectionAfterAutomaticStartRestoresUnassignedBlock() throws {
        var run = try makeRun(sets: 1)
        try run.advance(at: date(40))
        try run.select(exercise(id: "squat"), at: date(100))
        XCTAssertTrue(run.tick(at: date(350)))
        XCTAssertEqual(run.currentResult?.exercise.id, "squat")
        try run.undoTransition(at: date(360))
        XCTAssertEqual(run.remaining(at: date(360)), 0)
        XCTAssertTrue(run.tick(at: date(360)))
        XCTAssertEqual(run.progress.stage, .choosingExercise)
        XCTAssertNil(run.currentResult)
        XCTAssertNil(run.queuedExercise)
        XCTAssertEqual(run.progress.results.count, 1)
        XCTAssertEqual(run.phaseElapsed(at: date(360)), 20)
    }

    func testQueuedExerciseRestoresAndWaitsThroughConsecutiveRestBlocks() throws {
        var run = try TrainingRun(plan: .init(blocks: [.init(kind: .rest, seconds: 20), .init(kind: .rest, seconds: 30),
                                                      .init(kind: .exercise, seconds: 120)]), at: origin)
        try run.select(exercise(), at: date(5))
        let disk = store()
        var archive = TrainingArchive(); archive.current = run
        try disk.write(archive)
        var restored = try XCTUnwrap(disk.read().current)
        XCTAssertEqual(restored.queuedExercise?.id, "bench")
        XCTAssertEqual(restored.queuedExerciseNumber, 1)
        XCTAssertTrue(restored.tick(at: date(25)))
        XCTAssertEqual(restored.progress.stage, .blockRest)
        XCTAssertNotNil(restored.queuedExercise)
        XCTAssertTrue(restored.tick(at: date(60)))
        XCTAssertEqual(restored.progress.stage, .series)
        XCTAssertEqual(restored.currentResult?.exercise.id, "bench")
        XCTAssertEqual(restored.phaseElapsed(at: date(60)), 10)
        XCTAssertNil(restored.queuedExercise)
        // Old archives have neither of the optional queue/undo additions.
        let old = try JSONEncoder().encode(try makeRun())
        let legacy = try JSONDecoder().decode(TrainingRun.self, from: old)
        XCTAssertNil(legacy.progress.queuedExercise)
        XCTAssertNil(legacy.undo?.pausedSecondsAtCheckpoint)
    }

    func testQueueRemainsBoundToItsEmptyBlockWhenGoingBackToEarlierExercises() throws {
        var run = try TrainingRun(plan: .daily, at: origin)
        try run.select(exercise(sets: 1), at: date(10))
        try run.advance(at: date(30)); try run.advance(at: date(40))
        try run.select(exercise(sets: 1, id: "squat"), at: date(50))
        try run.select(exercise(id: "press"), at: date(60))
        try run.returnToPreviousBlock(at: date(70)); try run.returnToPreviousBlock(at: date(80))
        // An already assigned later block must not lose its exercise or sets.
        XCTAssertEqual(run.queuedExerciseNumber, 3)
        try run.select(exercise(id: "row"), at: date(85))
        XCTAssertEqual(run.queuedExerciseNumber, 3)
        XCTAssertEqual(run.progress.results[1].exercise.id, "squat")
        try run.advance(at: date(90)); try run.advance(at: date(100))
        XCTAssertEqual(run.currentResult?.exercise.id, "squat")
        XCTAssertEqual(run.queuedExercise?.id, "row")
        try run.advance(at: date(110)); try run.advance(at: date(120))
        XCTAssertEqual(run.currentResult?.exercise.id, "row")
        XCTAssertNil(run.queuedExercise)
        XCTAssertEqual(run.progress.results.count, 3)
    }

    func testQueueRejectsInvalidSelectionsAndFullOrFinishedPlans() throws {
        var run = try makeRun()
        let original = run
        XCTAssertThrowsError(try run.select(exercise(sets: 0), at: date(20)))
        XCTAssertEqual(run, original)
        run.togglePause(at: date(30))
        XCTAssertFalse(run.canSelectExercise)
        XCTAssertThrowsError(try run.select(exercise(id: "squat"), at: date(40)))
        run.togglePause(at: date(50))
        try run.select(exercise(id: "squat"), at: date(60))
        run.finish(effort: nil, at: date(70))
        XCTAssertNil(run.queuedExercise)
        XCTAssertNil(run.progress.queuedExercise)
        XCTAssertThrowsError(try run.select(exercise(), at: date(80)))
        var last = try TrainingRun(plan: .init(blocks: [.init(kind: .exercise, seconds: 120)]), at: origin)
        try last.select(exercise(), at: date(10))
        XCTAssertFalse(last.canSelectExercise)
        XCTAssertThrowsError(try last.select(exercise(id: "squat"), at: date(20))) { error in
            XCTAssertEqual(error.localizedDescription, TrainingFailure.noAvailableExerciseBlock.localizedDescription)
        }
    }

    func testFinalSeriesUsesInterExerciseRestAndCompletesVariableSetCounts() throws {
        for sets in [1, 3, 4] {
            var run = try makeRun(rest: 0, sets: sets)
            for index in 1...sets { try run.advance(at: date(10 + Double(index) * 30)) }
            XCTAssertEqual(run.progress.stage, .blockRest)
            XCTAssertTrue(try XCTUnwrap(run.progress.results.first).isComplete)
            XCTAssertEqual(run.progress.results.first?.sets.count, sets)
            XCTAssertEqual(run.remaining(at: date(10 + Double(sets) * 30)), 300)
            XCTAssertEqual(run.progress.blockIndex, 1)
            XCTAssertTrue(run.tick(at: date(310 + Double(sets) * 30)))
            XCTAssertEqual(run.progress.stage, .choosingExercise)
            XCTAssertNil(run.currentResult)
            XCTAssertEqual(run.exerciseNumber, 2)
        }
    }

    func testRestAutoAdvancesAtDeadlineWithoutCountingClockTicks() throws {
        var run = try makeRun()
        try run.advance(at: date(40))
        XCTAssertEqual(run.progress.stage, .seriesRest)
        XCTAssertEqual(run.remaining(at: date(100)), 60)
        XCTAssertFalse(run.tick(at: date(159)))
        XCTAssertTrue(run.tick(at: date(175)))
        XCTAssertEqual(run.progress.stage, .series)
        XCTAssertEqual(run.seriesNumber, 2)
        XCTAssertEqual(run.phaseElapsed(at: date(175)), 15)
        XCTAssertNil(run.remaining(at: date(175)))
        XCTAssertFalse(run.tick(at: date(10_000))) // Exercise duration is open ended.
    }

    func testPauseFreezesRestAndWorkoutDuration() throws {
        var run = try makeRun()
        try run.advance(at: date(40))
        run.togglePause(at: date(70))
        XCTAssertEqual(run.remaining(at: date(500)), 90)
        XCTAssertFalse(run.tick(at: date(500)))
        XCTAssertFalse(run.canAdvance)
        run.togglePause(at: date(170))
        XCTAssertEqual(run.remaining(at: date(200)), 60)
        XCTAssertEqual(run.elapsed(at: date(200)), 100)
        XCTAssertTrue(run.tick(at: date(260)))
        XCTAssertEqual(run.phaseElapsed(at: date(260)), 0)
    }

    func testPausedSeriesRetainsActualStartAndExcludesPauseFromDuration() throws {
        var run = try makeRun()
        run.togglePause(at: date(20)); run.togglePause(at: date(50))
        try run.advance(at: date(60))
        let result = try XCTUnwrap(run.currentResult?.sets.first)
        XCTAssertEqual(result.startedAt, date(10))
        XCTAssertEqual(result.endedAt, date(60))
        XCTAssertEqual(result.duration, 20)
        XCTAssertEqual(run.elapsed(at: date(60)), 30)
    }

    func testFinishDuringPauseKeepsIncompleteExerciseAndAccurateDuration() throws {
        var run = try makeRun()
        run.togglePause(at: date(25)); run.finish(effort: 7, at: date(100))
        XCTAssertFalse(run.isActive)
        XCTAssertEqual(run.elapsed(at: date(500)), 25)
        XCTAssertEqual(run.phaseElapsed(at: date(500)), 15)
        XCTAssertEqual(run.effort, 7)
        XCTAssertFalse(try XCTUnwrap(run.progress.results.first).isComplete)
        XCTAssertFalse(run.canAdvance)
        XCTAssertFalse(run.tick(at: date(10_000)))
    }

    func testUndoAfterRestExpirationRestoresSeriesWithoutDuplicatingResults() throws {
        var run = try makeRun()
        try run.advance(at: date(40)); run.tick(at: date(200))
        try run.undoTransition(at: date(210))
        XCTAssertEqual(run.progress.stage, .series)
        XCTAssertEqual(run.seriesNumber, 1)
        XCTAssertEqual(run.phaseElapsed(at: date(210)), 30)
        XCTAssertTrue(try XCTUnwrap(run.currentResult).sets.isEmpty)
        XCTAssertThrowsError(try run.undoTransition(at: date(220)))
    }

    func testUndoLastSeriesRestoresIncompleteExercise() throws {
        var run = try makeRun(sets: 1)
        try run.advance(at: date(40))
        XCTAssertTrue(run.progress.results[0].isComplete)
        try run.undoTransition(at: date(50))
        XCTAssertFalse(run.progress.results[0].isComplete)
        XCTAssertEqual(run.progress.blockIndex, 0)
        XCTAssertEqual(run.progress.stage, .series)
    }

    func testPreviousBlockReopensOnlyLastSeriesAndCanBeUndone() throws {
        var run = try makeRun(rest: 0, sets: 3)
        for seconds in [30.0, 50, 70] { try run.advance(at: date(seconds)) }
        let completed = run.progress.results[0]
        let revision = run.revision
        try run.returnToPreviousBlock(at: date(80))
        XCTAssertEqual(run.progress.blockIndex, 0)
        XCTAssertEqual(run.progress.stage, .series)
        XCTAssertEqual(run.seriesNumber, 3)
        XCTAssertEqual(run.currentResult?.sets, Array(completed.sets.prefix(2)))
        XCTAssertEqual(run.phaseElapsed(at: date(85)), 5)
        XCTAssertEqual(run.elapsed(at: date(85)), 85)
        XCTAssertEqual(run.revision, revision + 1)
        try run.undoTransition(at: date(90))
        XCTAssertEqual(run.progress.stage, .blockRest)
        XCTAssertEqual(run.progress.results[0], completed)
    }

    func testPreviousBlockPreservesLaterSetsAndAdvancesTheCorrectExercise() throws {
        var run = try makeRun(rest: 0, sets: 1)
        try run.advance(at: date(30))
        try run.advance(at: date(40))
        try run.select(exercise(sets: 3, id: "squat"), at: date(50))
        try run.advance(at: date(60))
        let laterSet = try XCTUnwrap(run.currentResult?.sets.first)
        try run.returnToPreviousBlock(at: date(70)) // Previous timed rest, restarted in full.
        XCTAssertEqual(run.progress.stage, .blockRest)
        XCTAssertEqual(run.remaining(at: date(70)), 300)
        try run.returnToPreviousBlock(at: date(80))
        XCTAssertEqual(run.currentResult?.exercise.id, "bench")
        XCTAssertEqual(run.currentResult?.sets.count, 0)
        try run.advance(at: date(90))
        XCTAssertEqual(run.progress.results[0].sets.count, 1)
        XCTAssertEqual(run.progress.results[1].sets, [laterSet])
        try run.advance(at: date(100))
        XCTAssertEqual(run.progress.stage, .series)
        XCTAssertEqual(run.currentResult?.exercise.id, "squat")
        XCTAssertEqual(run.seriesNumber, 2)
        try run.advance(at: date(110))
        XCTAssertEqual(run.progress.results[0].sets.count, 1)
        XCTAssertEqual(run.progress.results[1].sets.count, 2)
        XCTAssertEqual(run.currentResult?.sets.last?.duration, 10)
    }

    func testPreviousBlockWorksAfterAllBlocksAndSurvivesRestore() throws {
        var run = try TrainingRun(plan: .init(blocks: [.init(kind: .exercise, seconds: 120)]), at: origin)
        try run.select(exercise(sets: 1), at: date(10))
        try run.advance(at: date(30))
        XCTAssertTrue(run.canReturnToPreviousBlock)
        try run.returnToPreviousBlock(at: date(40))
        var restored = try JSONDecoder().decode(TrainingRun.self, from: JSONEncoder().encode(run))
        XCTAssertEqual(restored.progress.stage, .series)
        XCTAssertEqual(restored.currentResult?.exercise.id, "bench")
        XCTAssertEqual(restored.currentResult?.sets.count, 0)
        try restored.advance(at: date(55))
        XCTAssertEqual(restored.progress.stage, .readyToFinish)
        XCTAssertEqual(restored.progress.results[0].sets.last?.duration, 15)
    }

    func testPreviousBlockIsUnavailableAtStartWhilePausedAndAfterFinish() throws {
        var run = try makeRun(sets: 1)
        XCTAssertFalse(run.canReturnToPreviousBlock)
        XCTAssertThrowsError(try run.returnToPreviousBlock(at: date(20)))
        try run.advance(at: date(30))
        run.togglePause(at: date(40))
        XCTAssertFalse(run.canReturnToPreviousBlock)
        XCTAssertThrowsError(try run.returnToPreviousBlock(at: date(50)))
        run.finish(effort: nil, at: date(60))
        XCTAssertFalse(run.canReturnToPreviousBlock)
        XCTAssertThrowsError(try run.returnToPreviousBlock(at: date(70)))
    }

    func testConsecutiveTimedBlocksCatchUpThenWaitForSelection() throws {
        var run = try TrainingRun(plan: .init(blocks: [.init(kind: .rest, seconds: 20), .init(kind: .rest, seconds: 30),
                                                      .init(kind: .exercise, seconds: 120)]), at: origin)
        XCTAssertTrue(run.tick(at: date(70)))
        XCTAssertEqual(run.progress.blockIndex, 2)
        XCTAssertEqual(run.progress.stage, .choosingExercise)
        XCTAssertEqual(run.phaseElapsed(at: date(70)), 20)
        XCTAssertEqual(run.revision, 2)
    }

    func testFinishingLastBlockWaitsForExplicitWorkoutFinish() throws {
        var run = try TrainingRun(plan: .init(blocks: [.init(kind: .exercise, seconds: 120)]), at: origin)
        try run.select(exercise(sets: 1), at: date(10)); try run.advance(at: date(40))
        XCTAssertEqual(run.progress.stage, .readyToFinish)
        XCTAssertTrue(run.isActive)
        XCTAssertFalse(run.canAdvance)
        run.finish(effort: nil, at: date(50))
        XCTAssertEqual(run.elapsed(at: date(500)), 50)
    }

    func testArchiveRoundTripRestoresTimersUndoAndMissingMetrics() throws {
        var run = try makeRun(); try run.advance(at: date(40))
        var archive = TrainingArchive(); archive.current = run
        let store = store(); try store.write(archive)
        var restored = try XCTUnwrap(store.read().current)
        XCTAssertEqual(restored, run)
        XCTAssertNil(restored.metrics.heartRate)
        XCTAssertNil(restored.metrics.totalCalories)
        XCTAssertTrue(restored.tick(at: date(200)))
        try restored.undoTransition(at: date(210))
        XCTAssertEqual(restored.progress.stage, .series)
    }

    func testPhoneSnapshotsCompleteOnceUndoAndIgnoreStaleUpdates() throws {
        let container = try container(); let context = container.mainContext
        let item = WorkoutExercise(title: "Bench Press", subtitle: "", details: "", numberOfSets: 1,
                                   reps: 8, increaseLoadNextTime: false, weight: 40)
        context.insert(item); try context.save()
        let controller = PhoneTrainingController(store: store(), activate: false)
        let activity = ExerciseActivityController(context: context, liveActivitiesEnabled: false)
        controller.attach(context: context, exerciseActivity: activity)
        var run = try makeRun(rest: 0, sets: 1)
        run.progress.results[0] = .init(id: run.progress.results[0].id, blockID: run.progress.results[0].blockID,
                                       exercise: exercise(sets: 1, id: try XCTUnwrap(item.stableID)))
        let stale = run
        controller.receive(.init(kind: .snapshot, run: run))
        XCTAssertTrue(activity.isActive(item))
        try run.advance(at: date(40))
        controller.receive(.init(kind: .snapshot, run: run))
        controller.receive(.init(kind: .snapshot, run: run))
        XCTAssertTrue(item.isDone)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
        controller.receive(.init(kind: .snapshot, run: stale))
        XCTAssertTrue(item.isDone)
        XCTAssertEqual(controller.run?.revision, run.revision)
        try run.undoTransition(at: date(50))
        controller.receive(.init(kind: .snapshot, run: run))
        XCTAssertFalse(item.isDone)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 0)
        try run.advance(at: date(60))
        controller.receive(.init(kind: .snapshot, run: run))
        XCTAssertTrue(item.isDone)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
    }

    func testPreviousBlockReconcilesReopenedCompletionWithoutDuplicatingHistory() throws {
        let container = try container()
        let context = container.mainContext
        let item = WorkoutExercise(title: "Bench Press", subtitle: "", details: "", numberOfSets: 1,
                                   reps: 8, increaseLoadNextTime: false, weight: 40)
        context.insert(item); try context.save()
        let controller = PhoneTrainingController(store: store(), activate: false)
        controller.attach(context: context, exerciseActivity: ExerciseActivityController(context: context, liveActivitiesEnabled: false))
        var run = try TrainingRun(plan: .daily, at: origin)
        try run.select(exercise(sets: 1, id: try XCTUnwrap(item.stableID)), at: date(10))
        try run.advance(at: date(30))
        controller.receive(.init(kind: .snapshot, run: run))
        XCTAssertTrue(item.isDone)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
        try run.returnToPreviousBlock(at: date(40))
        controller.receive(.init(kind: .snapshot, run: run))
        XCTAssertFalse(item.isDone)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 0)
        try run.advance(at: date(50))
        controller.receive(.init(kind: .snapshot, run: run))
        controller.receive(.init(kind: .snapshot, run: run))
        XCTAssertTrue(item.isDone)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
    }

    func testPhoneShowsQueuedExerciseWithoutStartingOrCompletingItEarly() throws {
        let container = try container()
        let context = container.mainContext
        let item = WorkoutExercise(title: "Squat", subtitle: "", details: "", numberOfSets: 1,
                                   reps: 8, increaseLoadNextTime: false, weight: 40)
        context.insert(item)
        item.isDone = true
        try context.save()
        let controller = PhoneTrainingController(store: store(), activate: false)
        let activity = ExerciseActivityController(context: context, liveActivitiesEnabled: false)
        controller.attach(context: context, exerciseActivity: activity)
        var run = try makeRun(sets: 1)
        try run.advance(at: date(40))
        try run.select(exercise(sets: 1, id: try XCTUnwrap(item.stableID)), at: date(100))
        controller.receive(.init(kind: .snapshot, run: run))
        XCTAssertTrue(activity.isQueued(item))
        XCTAssertFalse(activity.isActive(item))
        XCTAssertTrue(item.isDone, "Queuing doesn't change a previous completion before the block starts")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 0)
        XCTAssertTrue(run.tick(at: date(350)))
        controller.receive(.init(kind: .snapshot, run: run))
        XCTAssertFalse(activity.isQueued(item))
        XCTAssertTrue(activity.isActive(item))
        XCTAssertFalse(item.isDone)
        try run.advance(at: date(360))
        controller.receive(.init(kind: .snapshot, run: run))
        controller.receive(.init(kind: .snapshot, run: run))
        XCTAssertTrue(item.isDone)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
    }

    func testDeletedHistoryIsNotRecreatedByMetricsOrRelaunch() throws {
        let container = try container(); let context = container.mainContext
        let item = WorkoutExercise(title: "Bench Press", subtitle: "", details: "", numberOfSets: 1,
                                   reps: 8, increaseLoadNextTime: false, weight: 40)
        context.insert(item); try context.save()
        let store = store(); let controller = PhoneTrainingController(store: store, activate: false)
        let activity = ExerciseActivityController(context: context, liveActivitiesEnabled: false)
        controller.attach(context: context, exerciseActivity: activity)
        var run = try TrainingRun(plan: .daily, at: origin)
        try run.select(exercise(sets: 1, id: try XCTUnwrap(item.stableID)), at: date(10))
        try run.advance(at: date(40)); run.finish(effort: nil, at: date(50))
        controller.receive(.init(kind: .snapshot, run: run))
        try ExerciseHistory.delete(context.fetch(FetchDescriptor<ExerciseCompletion>()), in: context)
        run.metrics.averageHeartRate = 120; run.revision += 1
        controller.receive(.init(kind: .snapshot, run: run))
        let restored = PhoneTrainingController(store: store, activate: false)
        restored.attach(context: context, exerciseActivity: activity)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 0)
        XCTAssertEqual(restored.history.count, 1)
    }

    func testHistoryDeliveredBeforeAttachmentIsReconciledOnce() throws {
        let container = try container(); let context = container.mainContext
        let item = WorkoutExercise(title: "Bench Press", subtitle: "", details: "", numberOfSets: 1,
                                   reps: 8, increaseLoadNextTime: false, weight: 40)
        context.insert(item); try context.save()
        let controller = PhoneTrainingController(store: store(), activate: false)
        var run = try TrainingRun(plan: .daily, at: origin)
        try run.select(exercise(sets: 1, id: try XCTUnwrap(item.stableID)), at: date(10))
        try run.advance(at: date(40)); run.finish(effort: nil, at: date(50))
        controller.receive(.init(kind: .snapshot, run: run))
        controller.attach(context: context, exerciseActivity: .init(context: context, liveActivitiesEnabled: false))
        controller.attach(context: context, exerciseActivity: .init(context: context, liveActivitiesEnabled: false))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
    }

    func testOldWorkoutRecoveryUpdateDoesNotReplaceNewSession() throws {
        let controller = PhoneTrainingController(store: store(), activate: false)
        var old = try TrainingRun(plan: .daily, at: origin)
        old.finish(effort: nil, at: date(50))
        controller.receive(.init(kind: .snapshot, run: old))
        let new = try TrainingRun(plan: .daily, at: date(100))
        controller.receive(.init(kind: .snapshot, run: new))
        old.metrics.recoveryOneMinute = 20; old.revision += 1
        controller.receive(.init(kind: .snapshot, run: old))
        XCTAssertEqual(controller.run?.id, new.id)
        XCTAssertEqual(controller.history.first?.metrics.recoveryOneMinute, 20)
    }

    func testRelaunchDoesNotAcceptOlderMetricsFromSameRevision() throws {
        let store = store()
        let controller = PhoneTrainingController(store: store, activate: false)
        var run = try makeRun()
        run.metrics.averageHeartRate = 125
        controller.receive(.init(kind: .snapshot, sentAt: date(100), run: run))
        let restored = PhoneTrainingController(store: store, activate: false)
        run.metrics.averageHeartRate = 100
        restored.receive(.init(kind: .snapshot, sentAt: date(90), run: run))
        XCTAssertEqual(restored.run?.metrics.averageHeartRate, 125)
        run.metrics.averageHeartRate = 130
        restored.receive(.init(kind: .snapshot, sentAt: date(110), run: run))
        XCTAssertEqual(restored.run?.metrics.averageHeartRate, 130)
    }

    func testDelayedWatchCompletionPreservesStandaloneActiveExercise() async throws {
        let container = try container()
        let context = container.mainContext
        let item = WorkoutExercise(title: "Bench Press", subtitle: "", details: "", numberOfSets: 1,
                                   reps: 8, increaseLoadNextTime: false, weight: 40)
        context.insert(item)
        try context.save()
        let phone = PhoneTrainingController(store: store(), activate: false)
        let activity = ExerciseActivityController(context: context, liveActivitiesEnabled: false)
        phone.attach(context: context, exerciseActivity: activity)
        await activity.waitForPendingUpdates()
        activity.toggle(item, context: context)
        await activity.waitForPendingUpdates()
        let sessionID = activity.activeSessionID

        var old = try TrainingRun(plan: .daily, at: origin)
        try old.select(exercise(sets: 1, id: try XCTUnwrap(item.stableID)), at: date(10))
        try old.advance(at: date(40))
        old.finish(effort: nil, at: date(50))
        phone.receive(.init(kind: .snapshot, sentAt: date(51), run: old))
        await activity.waitForPendingUpdates()

        XCTAssertFalse(item.isDone)
        XCTAssertTrue(activity.isActive(item))
        XCTAssertEqual(activity.activeSessionID, sessionID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseCompletion>()), 1)
        XCTAssertEqual(phone.lastSyncedAt, date(51))
        XCTAssertFalse(phone.isConnected, "A background snapshot is not proof of a live command channel")
    }

    func testPlanSynchronizationIgnoresOlderContextAndDuplicatesAfterRelaunch() throws {
        var archive = TrainingArchive()
        var latest = TrainingPlan.daily
        latest.name = "Latest Plan"
        let message = TrainingEnvelope(kind: .plan, sentAt: date(100), plan: latest)
        XCTAssertTrue(archive.receivePlan(message))
        let data = try JSONEncoder().encode(archive)
        var restored = try JSONDecoder().decode(TrainingArchive.self, from: data)
        XCTAssertFalse(restored.receivePlan(.init(kind: .plan, sentAt: date(90), plan: .daily)))
        XCTAssertFalse(restored.receivePlan(message))
        XCTAssertEqual(restored.plan.name, "Latest Plan")
        XCTAssertTrue(restored.receivePlan(.init(kind: .plan, sentAt: date(110), plan: .daily)))
        XCTAssertEqual(restored.plan.name, TrainingPlan.daily.name)
    }

    func testTrainingScreensRenderForVisualInspection() async throws {
        let controller = PhoneTrainingController(store: store(), activate: false)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = .light
        defer { window.isHidden = true }
        func snapshot<V: View>(_ view: V, name: String) async throws {
            window.rootViewController = UIHostingController(rootView: view)
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(400))
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-training-\(name).png"))
        }
        try await snapshot(NavigationStack { TrainingView(controller: controller) }, name: "idle")
        try await snapshot(TrainingPlanEditor(plan: .daily, save: { _ in }), name: "structure")
        let now = Date.now
        var run = try TrainingRun(plan: .daily, at: now.addingTimeInterval(-90))
        try run.select(exercise(), at: now.addingTimeInterval(-80))
        try run.advance(at: now.addingTimeInterval(-40))
        run.metrics.heartRate = 122; run.metrics.activeCalories = 34
        controller.receive(.init(kind: .snapshot, run: run))
        try await snapshot(NavigationStack { TrainingView(controller: controller) }, name: "active")
    }
}
