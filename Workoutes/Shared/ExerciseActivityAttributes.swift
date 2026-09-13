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
    }
}
