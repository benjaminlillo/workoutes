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
        let accent = ThemeColor(rawValue: UserDefaults.standard.string(forKey: "appAccentColor") ?? "") ?? .primary
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
            accentColorHex: accent.color.toHex(),
            displayedWeight: unit.displayedWeight(from: safeWeight),
            weightUnitSymbol: unit.symbol,
            status: isDone ? .done : .playing
        )
    }
}

@MainActor
@Observable
final class ExerciseActivityController {
    private(set) var activeExerciseID: String?
    private(set) var activeStartedAt: Date?
    private(set) var activeSessionID: String?
    private(set) var isUpdating = false
    var errorMessage: String?

    @ObservationIgnored private var activity: Activity<ExerciseActivityAttributes>?
    @ObservationIgnored private var pendingOperation: Task<Void, Never>?
    @ObservationIgnored private var stateObservation: Task<Void, Never>?
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

    func isActive(_ exercise: WorkoutExercise) -> Bool {
        activeExerciseID != nil && activeExerciseID == exercise.activityID
    }

    func content(for exercise: WorkoutExercise) -> ExerciseActivityAttributes.ContentState {
        var state = exercise.activityContent
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
        enqueue {
            guard self.activeExerciseID != nil else {
                if self.activity != nil { await self.finish() }
                return
            }
            guard let exercise = exercises.first(where: {
                      !$0.isDeleted && $0.activityID == self.activeExerciseID
                  }), !exercise.isDone else {
                do { try self.cancelSession() }
                catch { self.errorMessage = error.localizedDescription; return }
                await self.finish()
                return
            }
            await self.publish(exercise)
        }
    }

    func restore() {
        enqueue {
            self.restoreSession()
            self.restoreCurrentActivity()
            if let exercise = self.session?.exercise { await self.publish(exercise) }
            else { await self.finish() }
        }
    }

    func waitForPendingUpdates() async {
        await pendingOperation?.value
    }

    func performLiveActivityAction(exerciseID: String, sessionID: String? = nil, complete: Bool, context: ModelContext) async throws {
        await waitForPendingUpdates()
        guard let sessionID, sessionID == activeSessionID,
              let exercise = session?.exercise, exercise.activityID == exerciseID,
              !exercise.isDeleted, !exercise.isDone, isActive(exercise) else { return }
        if complete {
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
        activeExerciseID = session?.exercise?.stableID
        activeSessionID = session?.id
        activeStartedAt = session?.startedAt
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
                context.insert(ExerciseCompletion(id: id, completedAt: finishedAt, exercise: exercise))
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
                activity = try Activity.request(attributes: ExerciseActivityAttributes(), content: content, pushType: nil)
                observeActivity()
            }
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
