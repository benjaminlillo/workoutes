import Foundation

struct TrainingArchive: Codable, Sendable {
    var plan = TrainingPlan.daily
    var current: TrainingRun?
    var history: [TrainingRun] = []
    var handledCommands: [UUID] = []
    // Persist receipts so a reconnect doesn't recreate history the user deliberately deleted.
    var reconciledRevisions: [String: Int]? = [:]
    var receivedSnapshotDates: [String: Date]? = [:]
    var receivedPlanDate: Date?

    mutating func receivePlan(_ envelope: TrainingEnvelope) -> Bool {
        guard envelope.kind == .plan, let plan = envelope.plan, plan.isValid,
              receivedPlanDate.map({ envelope.sentAt > $0 }) ?? true else { return false }
        self.plan = plan
        receivedPlanDate = envelope.sentAt
        return true
    }
}

@MainActor
final class TrainingStore {
    private let url: URL
    init(url: URL? = nil) {
        self.url = url ?? URL.applicationSupportDirectory.appending(path: "Training/training.json")
    }
    func read() throws -> TrainingArchive {
        guard FileManager.default.fileExists(atPath: url.path) else { return TrainingArchive() }
        return try JSONDecoder().decode(TrainingArchive.self, from: Data(contentsOf: url))
    }
    func write(_ archive: TrainingArchive) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(archive).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
