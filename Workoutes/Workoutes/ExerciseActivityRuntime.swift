import SwiftData

@MainActor
final class ExerciseActivityRuntime {
    static let shared = ExerciseActivityRuntime()
    let container: ModelContainer
    let controller: ExerciseActivityController

    private init() {
        let schema = Schema([Workout.self, WorkoutExercise.self, Tag.self, ExerciseSession.self, ExerciseCompletion.self])
        do {
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
            try CatalogIdentity.backfill(in: container.mainContext)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        controller = ExerciseActivityController(context: container.mainContext)
    }
}
