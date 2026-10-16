import Foundation

struct TrainingCommand: Codable, Sendable {
    enum Action: String, Codable, Sendable { case start, selectExercise, advance, pause, undo, finish, retrySave, keepLocalRecord }
    var id = UUID()
    var createdAt = Date()
    var action: Action
    var runID: UUID?
    var revision: Int?
    var plan: TrainingPlan?
    var exercise: TrainingExercise?
    var effort: Int?
}

struct TrainingEnvelope: Codable, Sendable {
    enum Kind: String, Codable, Sendable { case snapshot, command, requestSnapshot, plan, failure }
    var kind: Kind
    var sentAt = Date()
    var run: TrainingRun?
    var command: TrainingCommand?
    var plan: TrainingPlan?
    var error: String?
}
