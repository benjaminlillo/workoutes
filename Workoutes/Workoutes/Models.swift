import Foundation
import SwiftData

@Model
final class Workout {
    var name: String
    @Relationship(inverse: \WorkoutExercise.workouts)
    var exercises: [WorkoutExercise]
    
    init(name: String, exercises: [WorkoutExercise] = []) {
        self.name = name
        self.exercises = exercises
    }
}

@Model
final class Tag {
    var name: String
    var colorHex: String
    
    @Relationship(inverse: \WorkoutExercise.tags)
    var exercises: [WorkoutExercise] = []
    
    init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
    }
}

@Model
final class WorkoutExercise {
    var title: String
    var subtitle: String
    var details: String
    var numberOfSets: Int
    var reps: Int
    var increaseLoadNextTime: Bool
    var isDone: Bool
    var isActive: Bool = false
    var weight: Double
    
    var workouts: [Workout] = []
    var tags: [Tag] = []
    
    init(title: String, subtitle: String, details: String, numberOfSets: Int, reps: Int, increaseLoadNextTime: Bool, weight: Double, isDone: Bool = false, isActive: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.details = details
        self.numberOfSets = numberOfSets
        self.reps = reps
        self.increaseLoadNextTime = increaseLoadNextTime
        self.weight = weight
        self.isDone = isDone
        self.isActive = isActive
    }
}
