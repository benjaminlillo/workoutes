import SwiftData
import Foundation

@MainActor
final class ExerciseActivityRuntime {
    static let shared = ExerciseActivityRuntime()
    let container: ModelContainer
    let controller: ExerciseActivityController
    let training: PhoneTrainingController

    private init() {
        let schema = Schema([Workout.self, WorkoutExercise.self, Tag.self, ExerciseSession.self, ExerciseCompletion.self])
        do {
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
            try CatalogIdentity.backfill(in: container.mainContext)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        controller = ExerciseActivityController(context: container.mainContext)
        #if DEBUG
        let isTesting = NSClassFromString("XCTestCase") != nil
        #else
        let isTesting = false
        #endif
        training = PhoneTrainingController(activate: !isTesting)
        // Live Activity intents can launch the app without constructing its UI.
        // Use the same restored exercise/training sources in either entry point.
        if !isTesting { training.attach(context: container.mainContext, exerciseActivity: controller) }
    }
}
