import Foundation

struct TrainingBlock: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable { case exercise, rest }
    var id = UUID()
    var kind: Kind
    // Exercise blocks use this only for the rest BETWEEN sets. Sets come from the exercise.
    var seconds: Int

    var isValid: Bool { seconds >= (kind == .rest ? 1 : 0) && seconds <= 3_600 }
}

struct TrainingPlan: Codable, Equatable, Sendable {
    var name = "Daily Training"
    var blocks: [TrainingBlock]

    static var daily: Self {
        Self(blocks: (0..<4).flatMap { index in
            [TrainingBlock(kind: .exercise, seconds: 120)] +
            (index < 3 ? [TrainingBlock(kind: .rest, seconds: 300)] : [])
        })
    }

    var exerciseCount: Int { blocks.filter { $0.kind == .exercise }.count }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 100 &&
        !blocks.isEmpty && blocks.count <= 40 && exerciseCount > 0 &&
        Set(blocks.map(\.id)).count == blocks.count && blocks.allSatisfy(\.isValid)
    }
}

struct TrainingExercise: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var weightKilograms: Double
    var repetitions: Int
    var sets: Int
    var usesPounds: Bool

    var isValid: Bool {
        !id.isEmpty && id.count <= 100 && !name.isEmpty && name.count <= 160 &&
        weightKilograms.isFinite && weightKilograms >= 0 &&
        (1...20).contains(sets) && (1...100).contains(repetitions)
    }
    var weightLabel: String {
        let value = usesPounds ? weightKilograms / 0.45359237 : weightKilograms
        return "\(value.formatted(.number.precision(.fractionLength(0...2)))) \(usesPounds ? "lb" : "kg")"
    }
}

enum TrainingFailure: LocalizedError {
    case invalidPlan, invalidExercise, wrongPhase, staleCommand, notConnected, noSession
    var errorDescription: String? {
        switch self {
        case .invalidPlan: "Add at least one exercise block and valid rest durations."
        case .invalidExercise: "This exercise needs a name, 1–20 sets, 1–100 repetitions and a valid weight."
        case .wrongPhase: "Select an exercise in an empty exercise block. Finish or undo the current series first."
        case .staleCommand: "The workout has advanced. Check the current stage and try again."
        case .notConnected: "The live connection to Apple Watch is unavailable. Keep both devices nearby and tap Refresh to reconnect. Any workout already running continues on the watch."
        case .noSession: "There is no active training session."
        }
    }
}
