import ActivityKit
import Foundation
import Observation
import SwiftData

extension WorkoutExercise {
    var activityID: String {
        // SwiftData identifiers survive app launches; no migration or exported session state is needed.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(persistentModelID).base64EncodedString()) ?? ""
    }

    var activityContent: ExerciseActivityAttributes.ContentState {
        .init(
            exerciseID: activityID,
            title: String(title.prefix(160)),
            subtitle: String(subtitle.prefix(160)),
            numberOfSets: numberOfSets,
            reps: reps,
            weight: weight.isFinite ? weight : 0,
            increaseLoadNextTime: increaseLoadNextTime
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
            let content = ActivityContent(state: exercise.activityContent, staleDate: nil)
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
                await self.finish()
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

    private func finish() async {
        let previous = activity
        activity = nil
        activeExerciseID = nil
        stateObservation?.cancel()
        await previous?.end(nil, dismissalPolicy: .immediate)
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
