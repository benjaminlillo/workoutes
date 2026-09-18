import AppIntents
import SwiftData

struct ExerciseLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Update Active Exercise"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Exercise ID") var exerciseID: String
    @Parameter(title: "Complete Exercise") var complete: Bool

    init() {}
    init(exerciseID: String, complete: Bool) {
        self.exerciseID = exerciseID
        self.complete = complete
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let runtime = ExerciseActivityRuntime.shared
        try await runtime.controller.performLiveActivityAction(
            exerciseID: exerciseID, complete: complete, context: runtime.container.mainContext
        )
        #endif
        return .result()
    }
}
