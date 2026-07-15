import Foundation
import ActivityKit

struct ExerciseAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isDone: Bool
        var weight: Double
        var reps: Int
        var sets: Int
    }
    
    var exerciseID: String
    var title: String
    var subtitle: String
}
