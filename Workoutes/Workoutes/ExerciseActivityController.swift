import ActivityKit
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ExerciseActivityController {
    private(set) var activeExerciseID: PersistentIdentifier?
    var isUpdating = false
    var errorMessage: String?

    init(context: ModelContext? = nil) {
        guard let context else { return }
        restoreActiveExercise(in: context)
        migrateLegacyLiveActivity(in: context)
    }

    func isActive(_ exercise: WorkoutExercise) -> Bool {
        exercise.isActive && activeExerciseID == exercise.persistentModelID
    }

    func advanceState(_ exercise: WorkoutExercise, context: ModelContext) {
        guard !exercise.isDeleted else { return }
        if isActive(exercise) {
            completeActive(context: context)
        } else if exercise.isDone {
            exercise.isDone = false
        } else {
            activate(exercise, context: context)
        }
        save(context)
    }

    func toggle(_ exercise: WorkoutExercise, context: ModelContext) {
        guard !exercise.isDeleted else { return }
        if isActive(exercise) {
            deactivateActive(context: context)
        } else {
            activate(exercise, context: context)
        }
        save(context)
    }

    func activate(_ exercise: WorkoutExercise, context: ModelContext) {
        deactivateActive(context: context)
        exercise.isDone = false
        exercise.isActive = true
        activeExerciseID = exercise.persistentModelID
        save(context)
    }

    func completeActive(context: ModelContext) {
        guard let exercise = activeExercise(in: context) else { return }
        complete(exercise, context: context)
    }

    func complete(_ exercise: WorkoutExercise, context: ModelContext) {
        guard !exercise.isDeleted else { return }
        exercise.isActive = false
        exercise.isDone = true
        if activeExerciseID == exercise.persistentModelID {
            activeExerciseID = nil
        }
        save(context)
    }

    func deactivateActive(context: ModelContext) {
        activeExercise(in: context)?.isActive = false
        activeExerciseID = nil
        save(context)
    }

    func activeExercise(in context: ModelContext) -> WorkoutExercise? {
        guard let activeExerciseID,
              let exercise = context.model(for: activeExerciseID) as? WorkoutExercise,
              !exercise.isDeleted, exercise.isActive, !exercise.isDone else { return nil }
        return exercise
    }

    func synchronize(exercises: [WorkoutExercise]) {
        let active = exercises.first { !$0.isDeleted && $0.isActive && !$0.isDone }
        for duplicate in exercises where duplicate.isActive && duplicate !== active {
            duplicate.isActive = false
        }
        activeExerciseID = active?.persistentModelID
    }

    func restore() {}
    func waitForPendingUpdates() async {}

    private func restoreActiveExercise(in context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutExercise>()
        let exercises = (try? context.fetch(descriptor)) ?? []
        synchronize(exercises: exercises)
    }

    private func migrateLegacyLiveActivity(in context: ModelContext) {
        let legacy = Activity<ExerciseActivityAttributes>.activities
        if activeExerciseID == nil,
           let encodedID = legacy.first?.content.state.exerciseID,
           let data = Data(base64Encoded: encodedID),
           let identifier = try? JSONDecoder().decode(PersistentIdentifier.self, from: data),
           let exercise = context.model(for: identifier) as? WorkoutExercise, !exercise.isDeleted {
            exercise.isActive = true
            exercise.isDone = false
            activeExerciseID = identifier
            save(context)
        }
        for activity in legacy {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func save(_ context: ModelContext) {
        do { try context.save() }
        catch { errorMessage = "Couldn't save this exercise: \(error.localizedDescription)" }
    }
}
