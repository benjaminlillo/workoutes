import Foundation

extension ExerciseCompletionSnapshot {
    @MainActor
    init(exercise: WorkoutExercise) {
        self.init(title: exercise.title, subtitle: exercise.subtitle, details: exercise.details,
                  numberOfSets: exercise.numberOfSets, reps: exercise.reps, weight: exercise.weight,
                  increaseLoadNextTime: exercise.increaseLoadNextTime,
                  tags: exercise.tags.map { Tag(name: $0.name, colorHex: $0.colorHex, iconName: $0.iconName) })
    }
}
