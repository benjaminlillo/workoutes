import Foundation
import SwiftData

@Model
final class Workout {
    var name: String
    var backgroundID: String?
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
    var weight: Double
    var isActive: Bool = false
    
    var workouts: [Workout] = []
    var tags: [Tag] = []
    
    init(title: String, subtitle: String, details: String, numberOfSets: Int, reps: Int, increaseLoadNextTime: Bool, weight: Double, isDone: Bool = false) {
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

enum SessionBlockKind: String, Codable, CaseIterable {
    case exercise
    case rest
}

struct SessionTemplateSnapshotBlock: Codable, Hashable, Identifiable {
    let id: UUID
    let order: Int
    let name: String
    let kindRawValue: String
    let duration: TimeInterval

    var kind: SessionBlockKind {
        SessionBlockKind(rawValue: kindRawValue) ?? .exercise
    }

    init(block: SessionTemplateBlock) {
        id = block.id
        order = block.order
        name = block.name
        kindRawValue = block.kindRawValue
        duration = block.restDuration
    }
}

@Model
final class SessionTemplate {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \SessionTemplateBlock.template)
    var blocks: [SessionTemplateBlock] = []

    init(name: String) { self.name = name }
}

@Model
final class SessionTemplateBlock {
    var id: UUID = UUID()
    var order: Int
    var name: String
    var kindRawValue: String
    var restDuration: TimeInterval
    var template: SessionTemplate?

    var kind: SessionBlockKind {
        get { SessionBlockKind(rawValue: kindRawValue) ?? .exercise }
        set { kindRawValue = newValue.rawValue }
    }

    init(order: Int, name: String, kind: SessionBlockKind, restDuration: TimeInterval = 60) {
        self.order = order
        self.name = name
        kindRawValue = kind.rawValue
        self.restDuration = restDuration
    }
}

@Model
final class TrainingSession {
    var id: UUID = UUID()
    var templateName: String
    var startedAt: Date
    var endedAt: Date?
    var endedEarly: Bool = false
    var templateSnapshotData: Data?
    @Relationship(deleteRule: .cascade, inverse: \SessionBlockRecord.session)
    var blocks: [SessionBlockRecord] = []

    var templateSnapshot: [SessionTemplateSnapshotBlock] {
        get {
            guard let templateSnapshotData else { return [] }
            return (try? JSONDecoder().decode([SessionTemplateSnapshotBlock].self, from: templateSnapshotData)) ?? []
        }
        set {
            templateSnapshotData = try? JSONEncoder().encode(newValue)
        }
    }

    init(templateName: String, startedAt: Date = Date()) {
        self.templateName = templateName
        self.startedAt = startedAt
    }
}

@Model
final class SessionBlockRecord {
    var id: UUID = UUID()
    var order: Int
    var configuredName: String
    var resolvedName: String?
    var kindRawValue: String
    var plannedRestDuration: TimeInterval
    var startedAt: Date?
    var endedAt: Date?
    var sourceTemplateBlockID: UUID?
    var exerciseIdentifierData: Data?
    var exerciseTitle: String?
    var exerciseGroupID: UUID?
    var setIndex: Int?
    var setCount: Int?
    var isInterSetRestValue: Bool?
    var session: TrainingSession?

    var kind: SessionBlockKind {
        get { SessionBlockKind(rawValue: kindRawValue) ?? .exercise }
        set { kindRawValue = newValue.rawValue }
    }

    var measuredDuration: TimeInterval? {
        guard let startedAt, let endedAt else { return nil }
        return max(0, endedAt.timeIntervalSince(startedAt))
    }

    var isInterSetRest: Bool { isInterSetRestValue == true }

    var isExerciseGroupBlock: Bool { exerciseGroupID != nil }

    init(
        order: Int,
        configuredName: String,
        kind: SessionBlockKind,
        plannedRestDuration: TimeInterval,
        sourceTemplateBlockID: UUID? = nil
    ) {
        self.order = order
        self.configuredName = configuredName
        kindRawValue = kind.rawValue
        self.plannedRestDuration = plannedRestDuration
        self.sourceTemplateBlockID = sourceTemplateBlockID
    }
}
