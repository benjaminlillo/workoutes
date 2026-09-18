import ActivityKit
import Foundation
import Observation
import SwiftData
import SwiftUI

extension WorkoutExercise {
    var activityID: String {
        // SwiftData identifiers survive app launches; no migration or exported session state is needed.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(persistentModelID).base64EncodedString()) ?? ""
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
    private(set) var isUpdating = false
    var errorMessage: String?

    @ObservationIgnored private var activity: Activity<ExerciseActivityAttributes>?
    @ObservationIgnored private var pendingOperation: Task<Void, Never>?
    @ObservationIgnored private var stateObservation: Task<Void, Never>?
    @ObservationIgnored private var queuedOperationCount = 0

    init() {
        restoreCurrentActivity()
    }

    func isActive(_ exercise: WorkoutExercise) -> Bool {
        activeExerciseID == exercise.activityID
    }

    /// Cycles the card control through empty, active, completed, and empty.
    func advanceState(_ exercise: WorkoutExercise, context: ModelContext) {
        guard !isUpdating, !exercise.isDeleted else { return }
        if isActive(exercise) {
            exercise.isDone = true
            enqueue { await self.finish(finalState: exercise.activityContent) }
        } else if exercise.isDone {
            exercise.isDone = false
        } else {
            toggle(exercise, context: context)
        }
    }

    func toggle(_ exercise: WorkoutExercise, context: ModelContext) {
        guard !isUpdating else { return }
        if isActive(exercise) {
            enqueue { await self.finish() }
            return
        }
        do {
            // Obtain a permanent identifier before passing it to the extension.
            try context.save()
        } catch {
            errorMessage = "Couldn't save this exercise: \(error.localizedDescription)"
            return
        }
        enqueue {
            guard !exercise.isDeleted else { return }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                self.errorMessage = "Live Activities are disabled. Enable them for Workoutes in Settings to show your active exercise."
                return
            }
            var state = exercise.activityContent
            state.status = .playing
            let content = ActivityContent(state: state, staleDate: nil)
            do {
                if let activity = self.activity, self.isRunning(activity) {
                    await activity.update(content)
                } else {
                    self.activity = try Activity.request(
                        attributes: ExerciseActivityAttributes(), content: content, pushType: nil
                    )
                    self.observeActivity()
                }
                exercise.isDone = false
                self.activeExerciseID = exercise.activityID
            } catch {
                self.errorMessage = "Couldn't start the Live Activity: \(error.localizedDescription)"
            }
        }
    }

    func synchronize(exercises: [WorkoutExercise]) {
        enqueue {
            guard let activity = self.activity else { return }
            guard self.isRunning(activity),
                  let exercise = exercises.first(where: {
                      !$0.isDeleted && $0.activityID == self.activeExerciseID
                  }), !exercise.isDone else {
                let finalState = exercises.first { !$0.isDeleted && $0.activityID == self.activeExerciseID && $0.isDone }?.activityContent
                await self.finish(finalState: finalState)
                return
            }
            let state = exercise.activityContent
            if state != activity.content.state {
                await activity.update(ActivityContent(state: state, staleDate: nil))
            }
        }
    }

    func restore() {
        enqueue { self.restoreCurrentActivity() }
    }

    func waitForPendingUpdates() async {
        await pendingOperation?.value
    }

    func performLiveActivityAction(exerciseID: String, complete: Bool, context: ModelContext) async throws {
        await waitForPendingUpdates()
        guard let data = Data(base64Encoded: exerciseID),
              let identifier = try? JSONDecoder().decode(PersistentIdentifier.self, from: data),
              let exercise = context.model(for: identifier) as? WorkoutExercise,
              !exercise.isDeleted, !exercise.isDone, isActive(exercise) else { return }
        if complete {
            exercise.isDone = true
            do { try context.save() }
            catch { exercise.isDone = false; throw error }
            enqueue { await self.finish(finalState: exercise.activityContent) }
        } else {
            exercise.increaseLoadNextTime.toggle()
            do { try context.save() }
            catch { exercise.increaseLoadNextTime.toggle(); throw error }
            synchronize(exercises: [exercise])
        }
        await waitForPendingUpdates()
    }

    private func restoreCurrentActivity() {
        let activities = Activity<ExerciseActivityAttributes>.activities.filter(isRunning)
        activity = activities.first
        activeExerciseID = activity?.content.state.exerciseID
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
                    self?.activeExerciseID = nil
                }
            }
        }
    }

    private func finish(finalState: ExerciseActivityAttributes.ContentState? = nil) async {
        let previous = activity
        activity = nil
        activeExerciseID = nil
        stateObservation?.cancel()
        let finalContent = finalState.map { ActivityContent(state: $0, staleDate: nil) }
        await previous?.end(finalContent, dismissalPolicy: finalState?.status == .done
                            ? .after(Date.now.addingTimeInterval(2)) : .immediate)
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
