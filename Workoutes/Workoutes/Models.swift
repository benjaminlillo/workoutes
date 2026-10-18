import Foundation
import SwiftData

@Model
final class Workout {
    // Optional for lightweight migration of existing stores; backfilled at startup.
    @Attribute(.unique) var stableID: String?
    var name: String
    var backgroundID: String?
    @Relationship(inverse: \WorkoutExercise.workouts)
    var exercises: [WorkoutExercise]
    
    init(name: String, exercises: [WorkoutExercise] = []) {
        self.stableID = UUID().uuidString
        self.name = name
        self.exercises = exercises
    }
}

@Model
final class Tag {
    @Attribute(.unique) var stableID: String?
    var name: String
    var colorHex: String
    // Optional so existing stores and tags retain their color-only appearance.
    var iconName: String?

    var muscleIcon: MuscleIcon? { iconName.flatMap(MuscleIcon.init(rawValue:)) }
    
    @Relationship(inverse: \WorkoutExercise.tags)
    var exercises: [WorkoutExercise] = []
    
    init(name: String, colorHex: String, iconName: String? = nil) {
        self.stableID = UUID().uuidString
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
    }
}

@Model
final class WorkoutExercise {
    @Attribute(.unique) var stableID: String?
    var title: String
    var subtitle: String
    var details: String
    var numberOfSets: Int
    var reps: Int
    var increaseLoadNextTime: Bool
    var isDone: Bool
    var weight: Double
    
    var workouts: [Workout] = []
    var tags: [Tag] = []
    @Relationship(deleteRule: .nullify, inverse: \ExerciseCompletion.exercise)
    var completions: [ExerciseCompletion] = []
    @Relationship(deleteRule: .nullify, inverse: \ExerciseSession.exercise)
    var sessions: [ExerciseSession] = []
    
    init(title: String, subtitle: String, details: String, numberOfSets: Int, reps: Int, increaseLoadNextTime: Bool, weight: Double, isDone: Bool = false) {
        self.stableID = UUID().uuidString
        self.title = title
        self.subtitle = subtitle
        self.details = details
        self.numberOfSets = numberOfSets
        self.reps = reps
        self.increaseLoadNextTime = increaseLoadNextTime
        self.weight = weight
        self.isDone = isDone
    }
}

@Model
final class ExerciseSession {
    @Attribute(.unique) var id: String
    var startedAt: Date
    var exercise: WorkoutExercise?

    init(exercise: WorkoutExercise, startedAt: Date) {
        id = UUID().uuidString
        self.exercise = exercise
        self.startedAt = startedAt
    }
}

@Model
final class ExerciseCompletion {
    @Attribute(.unique) var id: String
    var completedAt: Date
    var exercise: WorkoutExercise?
    // Optional for lightweight migration. Existing records must not acquire invented historical values.
    var snapshotData: Data? = nil

    init(id: String, completedAt: Date, exercise: WorkoutExercise?, snapshot: ExerciseCompletionSnapshot? = nil) {
        self.id = id
        self.completedAt = completedAt
        self.exercise = exercise
        self.snapshotData = snapshot.flatMap { try? JSONEncoder().encode($0) }
    }

    var snapshot: ExerciseCompletionSnapshot? {
        guard let snapshotData,
              let snapshot = try? JSONDecoder().decode(ExerciseCompletionSnapshot.self, from: snapshotData),
              snapshot.isValid else { return nil }
        return snapshot
    }

    var exerciseTitle: String { exercise?.title ?? "Exercise deleted" }
    var tagColors: [String] { exercise?.tags.map(\.colorHex) ?? [] }
}

@MainActor
enum CatalogIdentity {
    static func backfill(in context: ModelContext) throws {
        for workout in try context.fetch(FetchDescriptor<Workout>()) where workout.stableID == nil {
            workout.stableID = UUID().uuidString
        }
        for tag in try context.fetch(FetchDescriptor<Tag>()) where tag.stableID == nil {
            tag.stableID = UUID().uuidString
        }
        for exercise in try context.fetch(FetchDescriptor<WorkoutExercise>()) where exercise.stableID == nil {
            exercise.stableID = UUID().uuidString
        }
        if context.hasChanges { try context.save() }
    }
}
