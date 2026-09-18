import SwiftData

@MainActor
final class ExerciseActivityRuntime {
    static let shared = ExerciseActivityRuntime()
    let container: ModelContainer
    let controller: ExerciseActivityController

    private init() {
        let schema = Schema([Workout.self, WorkoutExercise.self])
        do {
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        controller = ExerciseActivityController()
    }
}
