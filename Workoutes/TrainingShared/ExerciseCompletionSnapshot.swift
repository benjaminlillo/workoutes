import Foundation

/// Value data captured at completion, independent of later catalog edits or deletion.
nonisolated struct ExerciseCompletionSnapshot: Codable, Equatable, Sendable {
    struct Tag: Codable, Equatable, Sendable {
        var name: String
        var colorHex: String
        var iconName: String?
    }

    var title: String
    var subtitle: String
    var details: String
    var numberOfSets: Int
    var reps: Int
    var weight: Double
    var increaseLoadNextTime: Bool
    var tags: [Tag]

    var isValid: Bool { weight.isFinite && weight >= 0 && numberOfSets >= 0 && reps >= 0 }
}
