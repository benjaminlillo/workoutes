import AppIntents
import Foundation

struct SessionLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Advance Session"
    static var description = IntentDescription("Advances to the next block or finishes the session.")

    @Parameter(title: "Session ID") var sessionID: String
    @Parameter(title: "Block ID") var blockID: String

    init() {}
    init(sessionID: String, blockID: String) {
        self.sessionID = sessionID
        self.blockID = blockID
    }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        guard let session = UUID(uuidString: sessionID), let block = UUID(uuidString: blockID) else { return .result() }
        await MainActor.run {
            ExerciseActivityRuntime.shared.sessionController.advance(expectedSessionID: session, expectedBlockID: block)
        }
        #endif
        return .result()
    }
}
