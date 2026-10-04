import Foundation
import SwiftData

struct ExportDataDTO: Codable {
    var workouts: [WorkoutDTO]
    var exercises: [WorkoutExerciseDTO]
    var tags: [TagDTO]
    var history: [ExerciseCompletionDTO]? = nil
}

struct WorkoutDTO: Codable { var id: String; var name: String }
struct TagDTO: Codable { var id: String; var name: String; var colorHex: String }
struct EntityRefDTO: Codable { var id: String }
struct WorkoutExerciseDTO: Codable {
    var id: String
    var title: String
    var subtitle: String
    var details: String
    var numberOfSets: Int
    var reps: Int
    var increaseLoadNextTime: Bool
    var isDone: Bool
    var weight: Double
    var workouts: [EntityRefDTO]
    var tags: [EntityRefDTO]
}
struct ExerciseCompletionDTO: Codable {
    var id: String
    var completedAt: Date
    var exerciseID: String?
}

@MainActor
enum DataBackup {
    enum ImportError: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            switch self { case .invalid(let message): return message }
        }
    }

    static func export(from context: ModelContext, includeHistory: Bool) throws -> Data {
        try CatalogIdentity.backfill(in: context)
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let tags = try context.fetch(FetchDescriptor<Tag>())
        let exercises = try context.fetch(FetchDescriptor<WorkoutExercise>())
        let payload = ExportDataDTO(
            workouts: workouts.map { .init(id: $0.stableID!, name: $0.name) },
            exercises: exercises.map {
                .init(id: $0.stableID!, title: $0.title, subtitle: $0.subtitle, details: $0.details,
                      numberOfSets: $0.numberOfSets, reps: $0.reps, increaseLoadNextTime: $0.increaseLoadNextTime,
                      isDone: $0.isDone, weight: $0.weight,
                      workouts: $0.workouts.map { .init(id: $0.stableID!) },
                      tags: $0.tags.map { .init(id: $0.stableID!) })
            },
            tags: tags.map { .init(id: $0.stableID!, name: $0.name, colorHex: $0.colorHex) },
            history: includeHistory ? try context.fetch(FetchDescriptor<ExerciseCompletion>()).map {
                .init(id: $0.id, completedAt: $0.completedAt, exerciseID: $0.exercise?.stableID)
            } : nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    static func importData(_ data: Data, into context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportDataDTO.self, from: data)
        try CatalogIdentity.backfill(in: context)
        var workouts = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Workout>()).map { ($0.stableID!, $0) })
        var tags = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Tag>()).map { ($0.stableID!, $0) })
        var exercises = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<WorkoutExercise>()).map { ($0.stableID!, $0) })
        var historyIDs = Set(try context.fetch(FetchDescriptor<ExerciseCompletion>()).map(\.id))
        try validate(payload, workoutIDs: Set(workouts.keys), tagIDs: Set(tags.keys), exerciseIDs: Set(exercises.keys))
        // Preserve pre-existing UI edits before beginning the import transaction.
        try context.save()
        do {
            for dto in payload.workouts {
                let workout = workouts[dto.id] ?? Workout(name: dto.name)
                if workouts[dto.id] == nil { workout.stableID = dto.id; context.insert(workout) }
                workout.name = dto.name
                workouts[dto.id] = workout
            }
            for dto in payload.tags {
                let tag = tags[dto.id] ?? Tag(name: dto.name, colorHex: dto.colorHex)
                if tags[dto.id] == nil { tag.stableID = dto.id; context.insert(tag) }
                tag.name = dto.name
                tag.colorHex = dto.colorHex
                tags[dto.id] = tag
            }
            for dto in payload.exercises {
                let exercise = exercises[dto.id] ?? WorkoutExercise(
                    title: dto.title, subtitle: dto.subtitle, details: dto.details, numberOfSets: dto.numberOfSets,
                    reps: dto.reps, increaseLoadNextTime: dto.increaseLoadNextTime, weight: dto.weight)
                if exercises[dto.id] == nil { exercise.stableID = dto.id; context.insert(exercise) }
                exercise.title = dto.title
                exercise.subtitle = dto.subtitle
                exercise.details = dto.details
                exercise.numberOfSets = dto.numberOfSets
                exercise.reps = dto.reps
                exercise.increaseLoadNextTime = dto.increaseLoadNextTime
                exercise.isDone = dto.isDone
                exercise.weight = dto.weight
                exercise.workouts = dto.workouts.compactMap { workouts[$0.id] }
                exercise.tags = dto.tags.compactMap { tags[$0.id] }
                exercises[dto.id] = exercise
            }
            for dto in payload.history ?? [] where !historyIDs.contains(dto.id) {
                context.insert(ExerciseCompletion(id: dto.id, completedAt: dto.completedAt,
                                                  exercise: dto.exerciseID.flatMap { exercises[$0] }))
                historyIDs.insert(dto.id)
            }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    private static func validate(_ payload: ExportDataDTO, workoutIDs: Set<String>, tagIDs: Set<String>, exerciseIDs: Set<String>) throws {
        for ids in [payload.workouts.map(\.id), payload.tags.map(\.id), payload.exercises.map(\.id), (payload.history ?? []).map(\.id)] {
            guard ids.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }), Set(ids).count == ids.count else {
                throw ImportError.invalid("Each item must have a nonempty, unique ID.")
            }
        }
        let allWorkouts = workoutIDs.union(payload.workouts.map(\.id))
        let allTags = tagIDs.union(payload.tags.map(\.id))
        let allExercises = exerciseIDs.union(payload.exercises.map(\.id))
        for dto in payload.exercises {
            guard dto.weight.isFinite, dto.weight >= 0, dto.numberOfSets >= 0, dto.reps >= 0,
                  dto.workouts.allSatisfy({ allWorkouts.contains($0.id) }), dto.tags.allSatisfy({ allTags.contains($0.id) }),
                  Set(dto.workouts.map(\.id)).count == dto.workouts.count,
                  Set(dto.tags.map(\.id)).count == dto.tags.count else {
                throw ImportError.invalid("Invalid exercise values or workout/tag references.")
            }
        }
        for dto in payload.history ?? [] {
            guard dto.exerciseID.map({ allExercises.contains($0) }) ?? true else {
                throw ImportError.invalid("History refers to an unknown exercise.")
            }
        }
    }
}
