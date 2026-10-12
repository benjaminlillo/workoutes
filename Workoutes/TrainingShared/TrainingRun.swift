import Foundation

struct TrainingSetResult: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    let startedAt: Date
    let endedAt: Date
    let duration: TimeInterval
}

struct TrainingExerciseResult: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let blockID: UUID
    let exercise: TrainingExercise
    var sets: [TrainingSetResult] = []
    var isComplete: Bool { sets.count == exercise.sets }
    var completedAt: Date? { isComplete ? sets.last?.endedAt : nil }
}

struct TrainingMetrics: Codable, Equatable, Sendable {
    struct Zone: Codable, Equatable, Identifiable, Sendable {
        var id: Int
        var seconds: TimeInterval
    }
    var heartRate: Double?
    var averageHeartRate: Double?
    var maximumHeartRate: Double?
    var activeCalories: Double?
    var basalCalories: Double?
    var recoveryOneMinute: Double?
    var currentZone: Int?
    var zones: [Zone] = []
    var totalCalories: Double? {
        guard let activeCalories, let basalCalories else { return nil }
        return activeCalories + basalCalories
    }
}

struct TrainingProgress: Codable, Equatable, Sendable {
    enum Stage: String, Codable, Sendable {
        case choosingExercise, series, seriesRest, blockRest, readyToFinish, finished
    }
    var blockIndex = 0
    var stage: Stage = .choosingExercise
    var phaseStartedAt: Date
    var phaseActualStartedAt: Date?
    var results: [TrainingExerciseResult] = []
}

struct TrainingUndo: Codable, Equatable, Sendable {
    var progress: TrainingProgress
    var phaseElapsed: TimeInterval
}

struct TrainingRun: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let plan: TrainingPlan
    let startedAt: Date
    var startCommandID: UUID?
    var revision = 0
    var progress: TrainingProgress
    var pausedAt: Date?
    var pausedSeconds: TimeInterval = 0
    var endedAt: Date?
    var undo: TrainingUndo?
    var metrics = TrainingMetrics()
    var effort: Int?
    var healthWorkoutID: UUID?
    var healthSaveError: String?
    var healthSaveSkipped: Bool?
    var isSimulatorPreview: Bool?
    var effortSaved = false

    init(plan: TrainingPlan, at date: Date, id: UUID = UUID()) throws {
        guard plan.isValid else { throw TrainingFailure.invalidPlan }
        self.id = id; self.plan = plan; startedAt = date
        progress = TrainingProgress(phaseStartedAt: date)
        enterBlock(at: date)
    }

    var isActive: Bool { endedAt == nil }
    var currentBlock: TrainingBlock? {
        plan.blocks.indices.contains(progress.blockIndex) ? plan.blocks[progress.blockIndex] : nil
    }
    var currentResult: TrainingExerciseResult? {
        guard let currentBlock else { return nil }
        return progress.results.first { $0.blockID == currentBlock.id }
    }
    var canSelectExercise: Bool { isActive && pausedAt == nil && progress.stage == .choosingExercise }
    var canAdvance: Bool {
        isActive && pausedAt == nil && [.series, .seriesRest, .blockRest].contains(progress.stage)
    }
    var exerciseNumber: Int {
        plan.blocks.prefix(progress.blockIndex + 1).filter { $0.kind == .exercise }.count
    }
    var seriesNumber: Int { min((currentResult?.sets.count ?? 0) + 1, currentResult?.exercise.sets ?? 1) }
    var phaseTitle: String {
        switch progress.stage {
        case .choosingExercise: "Choose an Exercise"
        case .series: "Series \(seriesNumber) of \(currentResult?.exercise.sets ?? 0)"
        case .seriesRest: "Rest · Next Series \(seriesNumber) of \(currentResult?.exercise.sets ?? 0)"
        case .blockRest: "Rest"
        case .readyToFinish: "All Blocks Complete"
        case .finished: "Training Complete"
        }
    }
    func elapsed(at date: Date) -> TimeInterval {
        max(0, (endedAt ?? pausedAt ?? date).timeIntervalSince(startedAt) - pausedSeconds)
    }
    func phaseElapsed(at date: Date) -> TimeInterval {
        max(0, (pausedAt ?? endedAt ?? date).timeIntervalSince(progress.phaseStartedAt))
    }
    var restDeadline: Date? {
        guard [.seriesRest, .blockRest].contains(progress.stage), let currentBlock else { return nil }
        return progress.phaseStartedAt.addingTimeInterval(TimeInterval(currentBlock.seconds))
    }
    func remaining(at date: Date) -> TimeInterval? {
        restDeadline.map { max(0, $0.timeIntervalSince(pausedAt ?? date)) }
    }

    mutating func select(_ exercise: TrainingExercise, at date: Date) throws {
        guard canSelectExercise, let block = currentBlock else { throw TrainingFailure.wrongPhase }
        guard exercise.isValid else { throw TrainingFailure.invalidExercise }
        checkpoint(at: date)
        progress.results.append(.init(id: "\(id.uuidString):\(block.id.uuidString)", blockID: block.id, exercise: exercise))
        progress.stage = .series
        progress.phaseStartedAt = date
        progress.phaseActualStartedAt = date
        revision += 1
    }

    mutating func advance(at date: Date) throws {
        guard canAdvance else { throw TrainingFailure.wrongPhase }
        checkpoint(at: date)
        switch progress.stage {
        case .series:
            guard let index = progress.results.indices.last else { throw TrainingFailure.wrongPhase }
            progress.results[index].sets.append(.init(startedAt: progress.phaseActualStartedAt ?? progress.phaseStartedAt, endedAt: date,
                                                     duration: phaseElapsed(at: date)))
            if progress.results[index].isComplete {
                progress.blockIndex += 1
                enterBlock(at: date)
            } else if currentBlock?.seconds == 0 {
                progress.phaseStartedAt = date
                progress.phaseActualStartedAt = date
            } else {
                progress.stage = .seriesRest; progress.phaseStartedAt = date; progress.phaseActualStartedAt = date
            }
        case .seriesRest:
            progress.stage = .series; progress.phaseStartedAt = date; progress.phaseActualStartedAt = date
        case .blockRest:
            progress.blockIndex += 1; enterBlock(at: date)
        default: throw TrainingFailure.wrongPhase
        }
        revision += 1
    }

    // Deadlines, rather than decrementing counters, survive backgrounding and disconnects.
    @discardableResult mutating func tick(at date: Date) -> Bool {
        guard isActive, pausedAt == nil else { return false }
        var changed = false
        while let deadline = restDeadline, date >= deadline {
            if progress.stage == .seriesRest {
                progress.stage = .series; progress.phaseStartedAt = deadline; progress.phaseActualStartedAt = deadline
            } else {
                progress.blockIndex += 1; enterBlock(at: deadline)
            }
            revision += 1; changed = true
        }
        return changed
    }

    mutating func togglePause(at date: Date) {
        guard isActive else { return }
        if let pausedAt {
            let interval = max(0, date.timeIntervalSince(pausedAt))
            pausedSeconds += interval
            progress.phaseStartedAt = progress.phaseStartedAt.addingTimeInterval(interval)
            self.pausedAt = nil
        } else { pausedAt = date }
        revision += 1
    }

    mutating func undoTransition(at date: Date) throws {
        guard isActive, pausedAt == nil, let undo else { throw TrainingFailure.wrongPhase }
        progress = undo.progress
        progress.phaseStartedAt = date.addingTimeInterval(-undo.phaseElapsed)
        self.undo = nil
        revision += 1
    }

    mutating func finish(effort: Int?, at date: Date) {
        guard isActive else { return }
        if let pausedAt {
            let interval = max(0, date.timeIntervalSince(pausedAt))
            pausedSeconds += interval
            progress.phaseStartedAt = progress.phaseStartedAt.addingTimeInterval(interval)
        }
        self.pausedAt = nil
        self.effort = effort.map { min(10, max(1, $0)) }
        endedAt = date; progress.stage = .finished; undo = nil; revision += 1
    }

    private mutating func checkpoint(at date: Date) {
        undo = TrainingUndo(progress: progress, phaseElapsed: phaseElapsed(at: date))
    }
    private mutating func enterBlock(at date: Date) {
        progress.phaseStartedAt = date
        progress.phaseActualStartedAt = date
        guard let currentBlock else { progress.stage = .readyToFinish; return }
        progress.stage = currentBlock.kind == .exercise ? .choosingExercise : .blockRest
    }
}

enum TrainingClock {
    static func label(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds.isFinite ? seconds : 0).rounded(.up))
        return value >= 3_600 ? String(format: "%d:%02d:%02d", value / 3_600, value / 60 % 60, value % 60)
            : String(format: "%d:%02d", value / 60, value % 60)
    }
}
