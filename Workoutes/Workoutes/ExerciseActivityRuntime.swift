import SwiftData

@MainActor
final class ExerciseActivityRuntime {
    static let shared = ExerciseActivityRuntime()
    let container: ModelContainer
    let controller: ExerciseActivityController
    let sessionController: SessionController

    private init() {
        let schema = Schema([
            Workout.self, WorkoutExercise.self, Tag.self,
            SessionTemplate.self, SessionTemplateBlock.self,
            TrainingSession.self, SessionBlockRecord.self
        ])
        do {
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        let context = container.mainContext
        controller = ExerciseActivityController(context: context)
        sessionController = SessionController(container: container, exerciseController: controller)
    }
}
