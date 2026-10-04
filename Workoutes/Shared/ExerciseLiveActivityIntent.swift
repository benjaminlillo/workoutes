import AppIntents
import SwiftData

struct ExerciseLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Update Active Exercise"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Exercise ID") var exerciseID: String
    @Parameter(title: "Complete Exercise") var complete: Bool
    @Parameter(title: "Session ID") var sessionID: String?

    init() {}
    init(exerciseID: String, sessionID: String? = nil, complete: Bool) {
        self.exerciseID = exerciseID
        self.sessionID = sessionID
        self.complete = complete
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let runtime = ExerciseActivityRuntime.shared
        try await runtime.controller.performLiveActivityAction(
            exerciseID: exerciseID, sessionID: sessionID, complete: complete, context: runtime.container.mainContext
        )
        #endif
        return .result()
    }
}
