import Foundation
import HealthKit
import Observation
import SwiftData

@MainActor
@Observable
final class PhoneTrainingController {
    private(set) var archive: TrainingArchive
    private(set) var isConnected = false
    private(set) var isStarting = false
    var errorMessage: String?
    @ObservationIgnored private let store: TrainingStore
    @ObservationIgnored private let commandSender: ((TrainingEnvelope) throws -> Void)?
    @ObservationIgnored private let connection = TrainingConnection()
    @ObservationIgnored private let healthStore = HKHealthStore()
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private weak var exerciseActivity: ExerciseActivityController?
    @ObservationIgnored private var startTimeout: Task<Void, Never>?
    @ObservationIgnored private var pendingStartID: UUID?

    var run: TrainingRun? { archive.current }
    var hasActiveSession: Bool { run?.isActive == true }
    var plan: TrainingPlan { archive.plan }
    var history: [TrainingRun] { archive.history.sorted { $0.startedAt > $1.startedAt } }

    init(store: TrainingStore? = nil, activate: Bool = true,
         commandSender: ((TrainingEnvelope) throws -> Void)? = nil) {
        self.store = store ?? TrainingStore()
        self.commandSender = commandSender
        do { archive = try self.store.read() }
        catch { archive = TrainingArchive(); errorMessage = "Couldn't restore training: \(error.localizedDescription)" }
        connection.onReceive = { [weak self] in self?.receive($0) }
        connection.onReachability = { [weak self] reachable in
            self?.isConnected = reachable
            if reachable { self?.requestSnapshot() }
        }
        connection.onError = { [weak self] in self?.errorMessage = $0 }
        if activate {
            connection.workoutChannel.listen(using: healthStore)
            connection.activate()
        }
    }

    func attach(context: ModelContext, exerciseActivity: ExerciseActivityController) {
        self.context = context; self.exerciseActivity = exerciseActivity
        exerciseActivity.training = self
        // A completion snapshot may have arrived while the phone app was not yet attached.
        do {
            var next = archive
            for run in archive.history + (run.map { $0.isActive ? [$0] : [] } ?? [])
                where (archive.reconciledRevisions?[run.id.uuidString] ?? -1) < run.revision {
                try reconcile(run, previous: nil)
                if next.reconciledRevisions == nil { next.reconciledRevisions = [:] }
                next.reconciledRevisions?[run.id.uuidString] = run.revision
            }
            try store.write(next); archive = next
            synchronizeActiveExercise()
        } catch { errorMessage = error.localizedDescription }
    }

    func savePlan(_ plan: TrainingPlan) throws {
        guard plan.isValid else { throw TrainingFailure.invalidPlan }
        var next = archive; next.plan = plan
        try store.write(next); archive = next
        // The phone owns the template; the active watch run keeps its original snapshot.
        if connection.isWatchInstalled { try connection.publish(.init(kind: .plan, plan: plan)) }
    }

    func start() async {
        guard !hasActiveSession, !isStarting else { return }
        guard connection.isWatchInstalled else {
            errorMessage = "Install Workoutes on your paired Apple Watch, then open it to connect."
            return
        }
        guard plan.isValid else { errorMessage = TrainingFailure.invalidPlan.localizedDescription; return }
        isStarting = true
        do {
            #if targetEnvironment(simulator)
            guard isConnected else {
                throw NSError(domain: "Training", code: 4, userInfo: [NSLocalizedDescriptionKey:
                    "Open Workoutes on your paired Apple Watch simulator before starting a preview."])
            }
            #else
            // Ask on the phone before delivering a start request to the companion.
            // An OK button on our error alert does not grant Health authorization.
            try await TrainingHealthAuthorization.request(using: healthStore)
            #endif
            let command = TrainingCommand(action: .start, plan: plan)
            pendingStartID = command.id
            // This short-lived request lets the HealthKit launch handler find the exact plan.
            try connection.publish(.init(kind: .command, command: command))
            #if !targetEnvironment(simulator)
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .traditionalStrengthTraining
            configuration.locationType = .indoor
            try await healthStore.startWatchApp(toHandle: configuration)
            #endif
            startTimeout?.cancel()
            startTimeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(120))
                guard !Task.isCancelled, self?.isStarting == true else { return }
                self?.isStarting = false
                self?.errorMessage = "Start wasn't confirmed. Open Workoutes on your watch and check Health permissions."
            }
        } catch { isStarting = false; pendingStartID = nil; errorMessage = error.localizedDescription }
    }

    func select(_ exercise: WorkoutExercise) {
        let unit = WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "") ?? .metric
        do {
            if let context { try CatalogIdentity.backfill(in: context) }
            guard let id = exercise.stableID, !exercise.isDeleted else { throw TrainingFailure.invalidExercise }
            let payload = TrainingExercise(id: id, name: String(exercise.title.prefix(160)),
                                           weightKilograms: exercise.weight, repetitions: exercise.reps,
                                           sets: exercise.numberOfSets, usesPounds: unit == .imperial,
                                           historySnapshot: ExerciseCompletionSnapshot(exercise: exercise))
            try send(.selectExercise, exercise: payload)
        } catch { errorMessage = error.localizedDescription }
    }

    func advance() { perform(.advance) }
    func clearQueuedExercise() { perform(.clearQueuedExercise) }
    func pause() { perform(.pause) }
    func undo() { perform(.undo) }
    func finish(effort: Int?) { perform(.finish, effort: effort) }
    func retrySave() { perform(.retrySave) }
    func keepLocalRecord() { perform(.keepLocalRecord) }
    func refresh() {
        connection.refresh()
    }
    private func requestSnapshot() {
        guard isConnected else { return }
        do {
            try connection.send(.init(kind: .requestSnapshot))
            try connection.send(.init(kind: .plan, plan: plan))
        } catch { errorMessage = error.localizedDescription }
    }

    private func perform(_ action: TrainingCommand.Action, effort: Int? = nil) {
        do { try send(action, effort: effort) } catch { errorMessage = error.localizedDescription }
    }
    private func send(_ action: TrainingCommand.Action, exercise: TrainingExercise? = nil, effort: Int? = nil) throws {
        guard let run else { throw TrainingFailure.noSession }
        let command = TrainingCommand(action: action, runID: run.id, revision: run.revision,
                                      exercise: exercise, effort: effort)
        let envelope = TrainingEnvelope(kind: .command, command: command)
        if let commandSender { try commandSender(envelope) }
        else { try connection.send(envelope) }
    }

    // Also used by tests to deliver out-of-order, duplicate and restored snapshots.
    func receive(_ envelope: TrainingEnvelope) {
        if envelope.kind == .failure {
            isStarting = false; pendingStartID = nil; errorMessage = envelope.error
            return
        }
        guard envelope.kind == .snapshot, let incoming = envelope.run,
              incoming.plan.isValid else { return }
        let previous = archive.current?.id == incoming.id ? archive.current : archive.history.first { $0.id == incoming.id }
        if let previous, incoming.revision < previous.revision { return }
        if let lastSeen = archive.receivedSnapshotDates?[incoming.id.uuidString],
           incoming.revision == previous?.revision, envelope.sentAt <= lastSeen { return }
        var next = archive
        if next.receivedSnapshotDates == nil { next.receivedSnapshotDates = [:] }
        next.receivedSnapshotDates?[incoming.id.uuidString] = envelope.sentAt
        if incoming.endedAt != nil {
            next.history.removeAll { $0.id == incoming.id }; next.history.append(incoming)
        }
        if next.current == nil || incoming.startedAt >= next.current!.startedAt {
            next.current = incoming
        }
        do {
            if previous?.revision != incoming.revision {
                try reconcile(incoming, previous: previous)
                if context != nil {
                    if next.reconciledRevisions == nil { next.reconciledRevisions = [:] }
                    next.reconciledRevisions?[incoming.id.uuidString] = incoming.revision
                }
            }
            try store.write(next)
            archive = next
            if incoming.isActive || (pendingStartID != nil && incoming.startCommandID == pendingStartID) {
                isStarting = false; pendingStartID = nil; startTimeout?.cancel()
            }
            if archive.current?.id == incoming.id { synchronizeActiveExercise() }
        } catch { errorMessage = "Couldn't save training: \(error.localizedDescription)" }
    }

    private func reconcile(_ incoming: TrainingRun, previous: TrainingRun?) throws {
        guard let context else { return }
        let affectsCurrent = archive.current == nil || incoming.startedAt >= archive.current!.startedAt
        try context.save()
        let exercises = try context.fetch(FetchDescriptor<WorkoutExercise>())
        let completed = incoming.progress.results.filter(\.isComplete)
        for result in completed where previous?.progress.results.contains(where: { $0.id == result.id && $0.isComplete }) != true {
            let id = result.id
            if try context.fetchCount(FetchDescriptor<ExerciseCompletion>(predicate: #Predicate { $0.id == id })) == 0,
               let exercise = exercises.first(where: { $0.stableID == result.exercise.id }),
               let completedAt = result.completedAt {
                // The watch run retains the values selected for this block, even if the catalog changes.
                context.insert(ExerciseCompletion(id: id, completedAt: completedAt, exercise: exercise,
                                                  snapshot: result.exercise.historySnapshot))
                if affectsCurrent { exercise.isDone = true }
            }
        }
        // Undo removes only the completion created by this block, never older exercise history.
        for result in previous?.progress.results.filter(\.isComplete) ?? [] where !completed.contains(where: { $0.id == result.id }) {
            let id = result.id
            for entry in try context.fetch(FetchDescriptor<ExerciseCompletion>(predicate: #Predicate { $0.id == id })) {
                context.delete(entry)
            }
            if affectsCurrent { exercises.first { $0.stableID == result.exercise.id }?.isDone = false }
        }
        if incoming.isActive, affectsCurrent, let result = incoming.currentResult, !result.isComplete {
            exercises.first { $0.stableID == result.exercise.id }?.isDone = false
        }
        do { try context.save() } catch { context.rollback(); throw error }
    }

    private func synchronizeActiveExercise() {
        guard let context, let exerciseActivity else { return }
        do { exerciseActivity.synchronize(exercises: try context.fetch(FetchDescriptor<WorkoutExercise>())) }
        catch { errorMessage = error.localizedDescription }
    }
}
