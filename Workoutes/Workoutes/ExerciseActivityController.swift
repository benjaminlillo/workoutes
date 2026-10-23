import ActivityKit
import Foundation
import Observation
import SwiftData
import SwiftUI

extension WorkoutExercise {
    var activityID: String {
        stableID ?? ""
    }

    var activityContent: ExerciseActivityAttributes.ContentState {
        let unit = WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "") ?? .metric
        let accent = ThemeColor.resolve(UserDefaults.standard.string(forKey: "appAccentColor"))
        let safeWeight = weight.isFinite ? weight : 0
        return .init(
            exerciseID: activityID,
            title: String(title.prefix(160)),
            subtitle: String(subtitle.prefix(160)),
            numberOfSets: numberOfSets,
            reps: reps,
            weight: safeWeight,
            increaseLoadNextTime: increaseLoadNextTime,
            details: String(details.prefix(200)),
            tagColors: tags.prefix(12).map { String($0.colorHex.prefix(8)) },
            tagIconNames: tags.prefix(12).map { $0.muscleIcon?.rawValue },
            // Live Activities and the Dynamic Island use a fixed dark surface.
            accentColorHex: accent.hex(for: .dark),
            displayedWeight: unit.displayedWeight(from: safeWeight),
            weightUnitSymbol: unit.symbol,
            status: isDone ? .done : .playing
        )
    }
}

@MainActor
@Observable
final class ExerciseActivityController {
    var training: PhoneTrainingController?
    private var localExerciseID: String?
    private var localStartedAt: Date?
    private var localSessionID: String?
    var activeExerciseID: String? { currentTrainingResult?.exercise.id ?? localExerciseID }
    var activeStartedAt: Date? {
        guard let result = currentTrainingResult, let run = training?.run else { return localStartedAt }
        return result.sets.first?.startedAt ?? run.progress.phaseActualStartedAt ?? run.progress.phaseStartedAt
    }
    var activeSessionID: String? {
        guard let result = currentTrainingResult, let run = training?.run else { return localSessionID }
        // A button rendered for an earlier series must not advance a later one.
        let phaseStart = run.progress.phaseActualStartedAt ?? run.progress.phaseStartedAt
        return "\(result.id):\(run.progress.stage.rawValue):\(result.sets.count):\(phaseStart.timeIntervalSinceReferenceDate)"
    }
    private(set) var isUpdating = false
    var errorMessage: String?

    @ObservationIgnored private var activity: Activity<ExerciseActivityAttributes>?
    @ObservationIgnored private var pendingOperation: Task<Void, Never>?
    @ObservationIgnored private var stateObservation: Task<Void, Never>?
    @ObservationIgnored private var awaitingForeground = false
    @ObservationIgnored private var queuedOperationCount = 0
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var session: ExerciseSession?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let liveActivitiesEnabled: Bool

    init(context: ModelContext? = nil, now: @escaping () -> Date = { .now }, liveActivitiesEnabled: Bool = true) {
        self.context = context
        self.now = now
        self.liveActivitiesEnabled = liveActivitiesEnabled
        restoreSession()
        restoreCurrentActivity()
    }

    private var currentTrainingResult: TrainingExerciseResult? {
        guard let run = training?.run, run.isActive, let result = run.currentResult, !result.isComplete else { return nil }
        return result
    }

    func isActive(_ exercise: WorkoutExercise) -> Bool {
        return activeExerciseID != nil && activeExerciseID == exercise.activityID
    }

    func isQueued(_ exercise: WorkoutExercise) -> Bool {
        training?.run?.queuedExercise?.id == exercise.activityID
    }

    func content(for exercise: WorkoutExercise) -> ExerciseActivityAttributes.ContentState {
        var state = exercise.activityContent
        if let selected = currentTrainingResult?.exercise, selected.id == exercise.activityID {
            state.title = selected.name
            state.numberOfSets = selected.sets
            state.reps = selected.repetitions
            state.weight = selected.weightKilograms
            let unit = WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "") ?? .metric
            state.displayedWeight = unit.displayedWeight(from: selected.weightKilograms)
            state.weightUnitSymbol = unit.symbol
        }
        if isActive(exercise) {
            state.status = .playing
            state.startedAt = activeStartedAt
            state.sessionID = activeSessionID
        }
        return state
    }

    /// Cycles the card control through empty, active, completed, and empty.
    func advanceState(_ exercise: WorkoutExercise, context: ModelContext) {
        guard !isUpdating, !exercise.isDeleted else { return }
        if let training, training.hasActiveSession, currentTrainingResult != nil || localExerciseID != exercise.activityID {
            if isActive(exercise) { training.advance() }
            else if isQueued(exercise) { training.clearQueuedExercise() }
            else { training.select(exercise) }
            return
        }
        if isActive(exercise) {
            toggle(exercise, context: context)
        } else if exercise.isDone {
            exercise.isDone = false
            do { try context.save() }
            catch { exercise.isDone = true; errorMessage = error.localizedDescription }
        } else {
            toggle(exercise, context: context)
        }
    }

    func toggle(_ exercise: WorkoutExercise, context: ModelContext) {
        guard !isUpdating, !exercise.isDeleted else { return }
        if let training, training.hasActiveSession, currentTrainingResult != nil || localExerciseID != exercise.activityID {
            if isActive(exercise) { training.advance() }
            else if isQueued(exercise) { training.clearQueuedExercise() }
            else { training.select(exercise) }
            return
        }
        self.context = context
        do {
            try context.save()
            try CatalogIdentity.backfill(in: context)
            if isActive(exercise) {
                let finalState = try finalize(exercise, context: context)
                enqueue { await self.finish(finalState: finalState) }
                return
            }
            // Switching cancels the old attempt regardless of its duration.
            if let session { context.delete(session) }
            let next = ExerciseSession(exercise: exercise, startedAt: now())
            context.insert(next)
            exercise.isDone = false
            try context.save()
            session = next
            updateActiveSession()
        } catch {
            context.rollback()
            restoreSession()
            errorMessage = "Couldn't save the exercise session: \(error.localizedDescription)"
            return
        }
        enqueue { await self.publish(exercise) }
    }

    func synchronize(exercises: [WorkoutExercise]) {
        enqueue { await self.synchronizeCurrentExercise(exercises: exercises) }
    }

    private func synchronizeCurrentExercise(exercises: [WorkoutExercise]) async {
        // Starting a tracker alone doesn't replace an active exercise. Only an
        // actual exercise selection takes over the single active-exercise slot.
        if currentTrainingResult != nil, session != nil {
            do { try cancelSession() }
            catch { errorMessage = error.localizedDescription; return }
        }
        guard let id = activeExerciseID else {
            if activity != nil { await finish() }
            return
        }
        guard let exercise = exercises.first(where: { !$0.isDeleted && $0.activityID == id }), !exercise.isDone else {
            do { try cancelSession() }
            catch { errorMessage = error.localizedDescription; return }
            await finish()
            return
        }
        await publish(exercise)
    }

    func restore() {
        enqueue {
            self.awaitingForeground = false
            self.restoreSession()
            self.restoreCurrentActivity()
            guard let context = self.context else { return }
            do {
                await self.synchronizeCurrentExercise(exercises: try context.fetch(FetchDescriptor<WorkoutExercise>()))
            } catch { self.errorMessage = error.localizedDescription }
        }
    }

    func waitForPendingUpdates() async {
        await pendingOperation?.value
    }

    func performLiveActivityAction(exerciseID: String, sessionID: String? = nil, complete: Bool, context: ModelContext) async throws {
        await waitForPendingUpdates()
        guard let sessionID, sessionID == activeSessionID,
              let exercise = try context.fetch(FetchDescriptor<WorkoutExercise>()).first(where: { $0.activityID == exerciseID }),
              !exercise.isDeleted, !exercise.isDone, isActive(exercise) else { return }
        if complete {
            if currentTrainingResult != nil {
                guard training?.run?.canAdvance == true else { return }
                training?.advance()
                return
            }
            try context.save()
            do {
                let finalState = try finalize(exercise, context: context)
                enqueue { await self.finish(finalState: finalState) }
            } catch { context.rollback(); restoreSession(); throw error }
        } else {
            exercise.increaseLoadNextTime.toggle()
            do { try context.save() }
            catch { exercise.increaseLoadNextTime.toggle(); throw error }
            synchronize(exercises: [exercise])
        }
        await waitForPendingUpdates()
    }

    private func restoreCurrentActivity() {
        guard liveActivitiesEnabled else { return }
        let activities = Activity<ExerciseActivityAttributes>.activities.filter(isRunning)
        activity = activities.first
        observeActivity()
        // Recover a single activity even if an earlier process left duplicates behind.
        for extra in activities.dropFirst() {
            enqueue { await extra.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func isRunning(_ activity: Activity<ExerciseActivityAttributes>) -> Bool {
        activity.activityState == .active || activity.activityState == .stale
    }

    private func observeActivity() {
        stateObservation?.cancel()
        guard let observed = activity else { return }
        stateObservation = Task { [weak self] in
            for await state in observed.activityStateUpdates {
                guard !Task.isCancelled else { return }
                if state == .ended || state == .dismissed,
                   self?.activity?.id == observed.id {
                    self?.activity = nil
                }
            }
        }
    }

    private func finish(finalState: ExerciseActivityAttributes.ContentState? = nil) async {
        let previous = activity
        activity = nil
        stateObservation?.cancel()
        let finalContent = finalState.map { ActivityContent(state: $0, staleDate: nil) }
        await previous?.end(finalContent, dismissalPolicy: finalState?.status == .done
                            ? .after(Date.now.addingTimeInterval(2)) : .immediate)
    }

    private func updateActiveSession() {
        localExerciseID = session?.exercise?.stableID
        localSessionID = session?.id
        localStartedAt = session?.startedAt
    }

    private func restoreSession() {
        guard let context else { return }
        do {
            let sessions = try context.fetch(FetchDescriptor<ExerciseSession>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
            session = sessions.first { $0.exercise != nil && $0.exercise?.isDone == false }
            for extra in sessions where extra.id != session?.id { context.delete(extra) }
            if context.hasChanges { try context.save() }
            updateActiveSession()
        } catch { errorMessage = "Couldn't restore the exercise session: \(error.localizedDescription)" }
    }

    private func cancelSession() throws {
        if let session, let context {
            try context.save()
            context.delete(session)
            do { try context.save() }
            catch { context.rollback(); restoreSession(); throw error }
        }
        session = nil
        updateActiveSession()
    }

    private func finalize(_ exercise: WorkoutExercise, context: ModelContext) throws -> ExerciseActivityAttributes.ContentState? {
        guard let session else { return nil }
        let finishedAt = now()
        let duration = finishedAt.timeIntervalSince(session.startedAt)
        let completed = duration > 10
        if completed {
            let id = session.id
            let existing = try context.fetch(FetchDescriptor<ExerciseCompletion>(predicate: #Predicate { $0.id == id }))
            if existing.isEmpty {
                context.insert(ExerciseCompletion(id: id, completedAt: finishedAt, exercise: exercise,
                                                  snapshot: ExerciseCompletionSnapshot(exercise: exercise)))
            }
        }
        var state = content(for: exercise)
        state.status = completed ? .done : .empty
        state.startedAt = nil
        state.elapsedSeconds = max(0, duration)
        exercise.isDone = completed
        context.delete(session)
        // The done flag, record and removal of the attempt commit together.
        try context.save()
        self.session = nil
        updateActiveSession()
        return completed ? state : nil
    }

    private func publish(_ exercise: WorkoutExercise) async {
        guard isActive(exercise), !exercise.isDeleted, liveActivitiesEnabled,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = content(for: exercise)
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            if let activity, isRunning(activity) {
                if state != activity.content.state { await activity.update(content) }
            } else {
                guard !awaitingForeground else { return }
                activity = try Activity.request(attributes: ExerciseActivityAttributes(), content: content, pushType: nil)
                observeActivity()
            }
        } catch ActivityAuthorizationError.visibility {
            // iOS can deny a new activity from a background snapshot. Foreground
            // restoration retries it; repeated snapshots shouldn't produce alerts.
            awaitingForeground = true
        } catch { errorMessage = "Exercise is running, but the Live Activity couldn't start: \(error.localizedDescription)" }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        queuedOperationCount += 1
        isUpdating = true
        let previous = pendingOperation
        pendingOperation = Task {
            await previous?.value
            await operation()
            queuedOperationCount -= 1
            isUpdating = queuedOperationCount > 0
        }
    }
}
