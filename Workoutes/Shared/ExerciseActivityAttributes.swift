import ActivityKit
import Foundation

nonisolated struct ExerciseActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseID: String
        var title: String
        var subtitle: String
        var numberOfSets: Int
        var reps: Int
        var weight: Double
        var increaseLoadNextTime: Bool
        var details: String? = nil
        var tagColors: [String]? = nil
        var accentColorHex: String? = nil
        var displayedWeight: Double? = nil
        var weightUnitSymbol: String? = nil
        var status: ExerciseStatus? = nil
    }
}

nonisolated enum ExerciseStatus: String, Codable {
    case empty
    case playing
    case done
}
