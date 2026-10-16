import Foundation
import HealthKit
import Observation
import WatchKit

@MainActor
@Observable
final class WatchTrainingController: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    static let shared = WatchTrainingController()
    private(set) var archive: TrainingArchive
    private(set) var isBusy = false
    private(set) var isConnected = false
    var errorMessage: String?
    @ObservationIgnored private let store = TrainingStore()
    @ObservationIgnored private let healthStore = HKHealthStore()
    @ObservationIgnored private let connection = TrainingConnection()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var recoveryTask: Task<Void, Never>?
    @ObservationIgnored private var lastMetricsPublish = Date.distantPast
    @ObservationIgnored private var collectionEnded = false
    @ObservationIgnored private var restored = false
    @ObservationIgnored private var restorationTask: Task<Void, Never>?
    @ObservationIgnored private var isSavingHealth = false
    @ObservationIgnored private var finishedWorkout: HKWorkout?

    var run: TrainingRun? { archive.current }
    var canStart: Bool { !isBusy && session == nil && (run?.healthSaveError == nil || run?.healthSaveSkipped == true) }

    override init() {
        do { archive = try store.read() }
        catch { archive = TrainingArchive(); errorMessage = "Couldn't restore training: \(error.localizedDescription)" }
        super.init()
        connection.onReceive = { [weak self] envelope in
            Task { @MainActor in await self?.receive(envelope) }
        }
        connection.onReachability = { [weak self] reachable in
            self?.isConnected = reachable
            if reachable { self?.publish() }
        }
        // A broken phone connection doesn't interrupt the workout or display repeated alerts.
        connection.onError = { _ in }
        connection.activate()
    }

    func restore() async {
        if let restorationTask { await restorationTask.value; return }
        let task = Task { await restoreSession() }
        restorationTask = task
        await task.value
    }

    private func restoreSession() async {
        isBusy = true
        defer { isBusy = false; restored = true }
        #if targetEnvironment(simulator)
        if archive.current == nil || archive.current?.isSimulatorPreview == true {
            if run?.isActive == true {
                _ = archive.current?.tick(at: .now)
                do { try persist(); startTimer() } catch { errorMessage = error.localizedDescription }
            }
            publish()
            return
        }
        #endif
        do {
            let recovered = try await healthStore.recoverActiveWorkoutSession()
            if let recovered, archive.current != nil {
                attach(recovered)
                if run?.isActive == true {
                    if recovered.state == .paused, archive.current?.pausedAt == nil { archive.current?.togglePause(at: .now) }
                    if recovered.state == .running, archive.current?.pausedAt != nil { archive.current?.togglePause(at: .now) }
                    _ = archive.current?.tick(at: .now)
                    try persist()
                    startTimer()
                }
                if recovered.state == .stopped {
                    if archive.current?.isActive == true { archive.current?.finish(effort: nil, at: recovered.endDate ?? .now) }
                    try persist()
                    await saveHealthWorkout()
                } else if archive.current?.isActive == false {
                    recovered.stopActivity(with: archive.current?.endedAt)
                }
                publish()
            } else if let recovered {
                // Don't leave an orphan sensor session running without a local progression.
                recovered.end()
            } else if let run, run.isActive {
                // Never show a restored timer as if the sensors were still recording.
                if let workout = try await savedWorkout(for: run) {
                    archive.current?.finish(effort: nil, at: workout.endDate)
                    record(workout)
                } else {
                    archive.current?.finish(effort: nil, at: .now)
                    archive.current?.healthSaveError = "The workout was interrupted and its HealthKit session could not be recovered. Your exercise records are preserved."
                }
                try persist(); publish(durable: true)
            } else if let run, run.healthWorkoutID == nil {
                await saveHealthWorkout()
            }
            if let run = archive.current, !run.isActive {
                await refreshRecovery(for: run.id)
            }
        } catch {
            if archive.current?.isActive == true {
                archive.current?.finish(effort: nil, at: .now)
                archive.current?.healthSaveError = error.localizedDescription
                try? persist(); publish(durable: true)
            }
            errorMessage = "Couldn't recover the workout: \(error.localizedDescription)"
        }
    }

    func handleLaunch() {
        Task {
            await restore()
            if let context = connection.receivedContext() { await receive(context) }
        }
    }

    func startFromWatch() { Task { await start(plan: archive.plan) } }

    private func authorize() async throws {
        try await TrainingHealthAuthorization.request(using: healthStore)
    }

    private func start(plan: TrainingPlan, commandID: UUID? = nil) async {
        guard !isBusy, run?.isActive != true else { publish(); return }
        guard canStart else {
            fail("Finish saving the previous workout before starting another one."); return
        }
        isBusy = true
        let previous = archive
        defer { isBusy = false }
        do {
            let date = Date.now
            var next = try TrainingRun(plan: plan, at: date)
            #if targetEnvironment(simulator)
            next.isSimulatorPreview = true
            next.healthSaveSkipped = true
            next.startCommandID = commandID
            archive.current = next
            if let commandID { archive.handledCommands.append(commandID) }
            try persist()
            startTimer(); publish(durable: true)
            #else
            try await authorize()
            // Recreate the start timestamp after the permission sheet, not before.
            next = try TrainingRun(plan: plan, at: .now, id: next.id)
            next.startCommandID = commandID
            archive.current = next
            if let commandID { archive.handledCommands.append(commandID) }
            try persist()
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .traditionalStrengthTraining; configuration.locationType = .indoor
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            attach(session)
            collectionEnded = false
            finishedWorkout = nil
            try await builder?.addMetadata([HKMetadataKeySyncIdentifier: next.id.uuidString,
                                            HKMetadataKeySyncVersion: 1,
                                            HKMetadataKeyWorkoutBrandName: "Workoutes"])
            session.startActivity(with: next.startedAt)
            try await builder?.beginCollection(at: next.startedAt)
            startTimer(); publish(durable: true)
            Task { await connection.workoutChannel.reconnect() }
            #endif
        } catch {
            builder?.discardWorkout(); session?.end(); session = nil; builder = nil
            archive = previous
            // The same request also arrives through launch, context and live messaging.
            // Remember failed attempts so dismissing an alert cannot replay them.
            if let commandID { archive.handledCommands.append(commandID) }
            try? persist()
            fail(error.localizedDescription)
        }
    }

    private func attach(_ session: HKWorkoutSession) {
        self.session = session; session.delegate = self
        connection.workoutChannel.attach(session)
        let builder = session.associatedWorkoutBuilder()
        self.builder = builder; builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: session.workoutConfiguration)
    }

    func local(_ action: TrainingCommand.Action, effort: Int? = nil) {
        guard let run else { return }
        Task { await receive(.init(kind: .command, command: .init(action: action, runID: run.id, revision: run.revision, effort: effort))) }
    }

    func refreshConnection() {
        connection.refresh()
        Task { await connection.workoutChannel.reconnect() }
        publish()
    }

    private func receive(_ envelope: TrainingEnvelope) async {
        guard restored else { await restore(); await receive(envelope); return }
        if envelope.kind == .requestSnapshot {
            publish()
            for historical in archive.history {
                // Keep bulk history off HealthKit's live-workout channel (100 KB / 10 seconds).
                try? connection.send(.init(kind: .snapshot, run: historical), allowsWorkoutChannel: false)
            }
            return
        }
        if envelope.kind == .plan, let plan = envelope.plan, plan.isValid {
            let previous = archive
            archive.plan = plan
            do { try persist() } catch { archive = previous; fail(error.localizedDescription) }
            return
        }
        guard envelope.kind == .command, let command = envelope.command else { return }
        if archive.handledCommands.contains(command.id) { publish(); return }
        if command.action == .start {
            guard abs(command.createdAt.timeIntervalSinceNow) < 120, let plan = command.plan else { return }
            await start(plan: plan, commandID: command.id); return
        }
        guard !isBusy else { fail("Please wait while the workout is being saved."); return }
        guard var run = archive.current, command.runID == run.id,
              command.revision == run.revision, abs(command.createdAt.timeIntervalSinceNow) < 30 else {
            fail(TrainingFailure.staleCommand.localizedDescription); publish(); return
        }
        let previous = archive
        var committedAutomaticTransition = false
        do {
            let date = Date.now
            // First bring an expired timer up to date so an old button cannot finish the next series.
            if run.tick(at: date) {
                archive.current = run; try persist(); publish(durable: true)
                committedAutomaticTransition = true
                WKInterfaceDevice.current().play(.notification)
                throw TrainingFailure.staleCommand
            }
            switch command.action {
            case .selectExercise:
                guard let exercise = command.exercise else { throw TrainingFailure.invalidExercise }
                try run.select(exercise, at: date)
            case .advance: try run.advance(at: date)
            case .pause: run.togglePause(at: date)
            case .undo: try run.undoTransition(at: date)
            case .finish: run.finish(effort: command.effort, at: date)
            case .retrySave:
                await saveHealthWorkout(); return
            case .keepLocalRecord:
                guard !run.isActive, run.healthSaveError != nil else { throw TrainingFailure.wrongPhase }
                run.healthSaveSkipped = true; run.revision += 1
            case .start: return
            }
            archive.current = run
            archive.handledCommands.append(command.id)
            try persist()
            if command.action == .keepLocalRecord {
                if run.healthWorkoutID == nil { builder?.discardWorkout() }
                session?.end(); session = nil; builder = nil
            }
            // Commit the progression before changing HealthKit or notifying the phone.
            if command.action == .pause { run.pausedAt == nil ? session?.resume() : session?.pause() }
            if command.action == .finish {
                timer?.cancel()
                if let session {
                    isBusy = true
                    session.stopActivity(with: date)
                } else { await saveHealthWorkout() }
            }
            WKInterfaceDevice.current().play(.click)
            publish(durable: true)
        } catch {
            // Preserve automatic timer transitions even when rejecting an outdated command.
            if !committedAutomaticTransition { archive = previous }
            fail(error.localizedDescription)
        }
    }

    private func startTimer() {
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, var run = self.archive.current, run.isActive else { return }
                // A phone relaunch or radio interruption can invalidate the mirrored session.
                // Retry in the background without pausing HealthKit or depending on an open Watch UI.
                if !self.connection.workoutChannel.isReachable {
                    Task { await self.connection.workoutChannel.reconnect() }
                }
                if run.tick(at: .now) {
                    let previous = self.archive
                    self.archive.current = run
                    do {
                        try self.persist()
                        WKInterfaceDevice.current().play(.notification)
                        self.publish(durable: true)
                    } catch { self.archive = previous; self.fail(error.localizedDescription) }
                }
            }
        }
    }

    private func persist() throws {
        archive.handledCommands = Array(archive.handledCommands.suffix(200))
        if let run = archive.current, !run.isActive {
            archive.history.removeAll { $0.id == run.id }; archive.history.append(run)
        }
        try store.write(archive)
    }

    private func publish(durable: Bool = false) {
        try? connection.publish(.init(kind: .snapshot, run: archive.current), durable: durable)
    }
    private func fail(_ message: String) {
        errorMessage = message
        try? connection.send(.init(kind: .failure, error: message))
    }

    private func saveHealthWorkout() async {
        guard !isSavingHealth else { return }
        guard let run = archive.current, !run.isActive else { isBusy = false; return }
        if run.isSimulatorPreview == true { isBusy = false; publish(durable: true); return }
        isSavingHealth = true
        isBusy = true
        defer { isBusy = false; isSavingHealth = false; publish(durable: true) }
        do {
            var workout = finishedWorkout
            if workout == nil { workout = try await savedWorkout(for: run) }
            if workout == nil, run.healthWorkoutID == nil, let builder {
                if !collectionEnded {
                    try await builder.endCollection(at: run.endedAt ?? .now)
                    collectionEnded = true
                }
                workout = try await builder.finishWorkout()
                finishedWorkout = workout
            }
            guard let workout else {
                throw NSError(domain: "Training", code: 2, userInfo: [NSLocalizedDescriptionKey: "No saved Health workout or recoverable builder was found. Exercise records are preserved."])
            }
            record(workout)
            archive.current?.healthSaveError = nil
            archive.current?.revision += 1
            try persist() // Store the workout identity before attempting effort; retries cannot duplicate it.
            session?.end(); session = nil; builder = nil
            if let effort = run.effort, archive.current?.effortSaved != true {
                let type = HKQuantityType(.workoutEffortScore)
                guard healthStore.authorizationStatus(for: type) == .sharingAuthorized else {
                    throw NSError(domain: "Training", code: 3, userInfo: [NSLocalizedDescriptionKey: "Workout saved. Allow effort ratings in Health to save your training effort."])
                }
                let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier,
                                               allowedValues: ["\(run.id.uuidString):effort"])
                ])
                let existing = try await samples(type: type, predicate: predicate)
                let sample = existing.first ?? HKQuantitySample(type: type, quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: Double(effort)),
                                                               start: workout.startDate, end: workout.endDate,
                                                               metadata: [HKMetadataKeySyncIdentifier: "\(run.id.uuidString):effort", HKMetadataKeySyncVersion: 1])
                if existing.isEmpty { try await healthStore.save(sample) }
                try await healthStore.relateWorkoutEffortSample(sample, with: workout, activity: nil)
                archive.current?.effortSaved = true
            }
            archive.current?.healthSaveError = nil; archive.current?.revision += 1
            archive.current?.healthSaveSkipped = false
            try persist()
            recoveryTask?.cancel()
            let runID = run.id
            recoveryTask = Task { [weak self] in
                for _ in 0..<8 {
                    try? await Task.sleep(for: .seconds(30))
                    guard !Task.isCancelled else { return }
                    await self?.refreshRecovery(for: runID)
                }
            }
        } catch {
            archive.current?.healthSaveError = error.localizedDescription
            archive.current?.revision += 1
            try? persist()
            errorMessage = "Health save needs attention: \(error.localizedDescription)"
        }
    }

    private func savedWorkout(for run: TrainingRun) async throws -> HKWorkout? {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [run.id.uuidString])
        return try await samples(type: HKObjectType.workoutType(), predicate: predicate).first as? HKWorkout
    }
    private func samples(type: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, results, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: results ?? []) }
            }
            healthStore.execute(query)
        }
    }
    private func record(_ workout: HKWorkout) {
        archive.current?.healthWorkoutID = workout.uuid
        let unit = HKUnit.count().unitDivided(by: .minute())
        let statistics = workout.statistics(for: HKQuantityType(.heartRate))
        archive.current?.metrics.averageHeartRate = statistics?.averageQuantity()?.doubleValue(for: unit)
        archive.current?.metrics.maximumHeartRate = statistics?.maximumQuantity()?.doubleValue(for: unit)
        archive.current?.metrics.activeCalories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        archive.current?.metrics.basalCalories = workout.statistics(for: HKQuantityType(.basalEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        updateZones(workout.zoneGroup(for: HKQuantityType(.heartRate)))
    }
    private func refreshRecovery(for id: UUID) async {
        guard let run = archive.current?.id == id ? archive.current : archive.history.first(where: { $0.id == id }),
              run.isSimulatorPreview != true,
              let endedAt = run.endedAt else { return }
        do {
            let predicate = HKQuery.predicateForSamples(withStart: run.startedAt, end: endedAt.addingTimeInterval(300), options: [])
            let found = try await samples(type: HKQuantityType(.heartRateRecoveryOneMinute), predicate: predicate)
                .compactMap { $0 as? HKQuantitySample }.first { sample in
                    guard sample.endDate >= endedAt, sample.endDate <= endedAt.addingTimeInterval(300),
                          let activity = sample.metadata?[HKMetadataKeyHeartRateRecoveryActivityType] as? NSNumber,
                          activity.uintValue == HKWorkoutActivityType.traditionalStrengthTraining.rawValue,
                          let duration = sample.metadata?[HKMetadataKeyHeartRateRecoveryActivityDuration] as? HKQuantity else { return false }
                    return abs(duration.doubleValue(for: .second()) - run.elapsed(at: endedAt)) < 5
                }
            guard let found else { return }
            let recovery = found.quantity.doubleValue(for: .count())
            guard recovery != run.metrics.recoveryOneMinute else { return }
            if archive.current?.id == id {
                archive.current?.metrics.recoveryOneMinute = recovery; archive.current?.revision += 1
            } else if let index = archive.history.firstIndex(where: { $0.id == id }) {
                archive.history[index].metrics.recoveryOneMinute = recovery; archive.history[index].revision += 1
            }
            try persist()
            if let updated = archive.current?.id == id ? archive.current : archive.history.first(where: { $0.id == id }) {
                try? connection.publish(.init(kind: .snapshot, run: updated), durable: true, replacesContext: archive.current?.id == id)
            }
        } catch { /* Data may be unavailable while the device is locked; retry on the next foreground launch. */ }
    }

    private func updateMetrics() {
        guard let builder, archive.current != nil else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let heartRate = builder.statistics(for: HKQuantityType(.heartRate))
        archive.current?.metrics.heartRate = heartRate?.mostRecentQuantity()?.doubleValue(for: unit)
        archive.current?.metrics.averageHeartRate = heartRate?.averageQuantity()?.doubleValue(for: unit)
        archive.current?.metrics.maximumHeartRate = heartRate?.maximumQuantity()?.doubleValue(for: unit)
        archive.current?.metrics.activeCalories = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        archive.current?.metrics.basalCalories = builder.statistics(for: HKQuantityType(.basalEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        updateZones(builder.zoneGroup(for: HKQuantityType(.heartRate)))
        if Date.now.timeIntervalSince(lastMetricsPublish) >= 5 {
            lastMetricsPublish = .now
            do { try persist(); publish() } catch { errorMessage = error.localizedDescription }
        }
    }
    private func updateZones(_ group: HKWorkoutZoneGroup?) {
        guard let group else { return }
        archive.current?.metrics.zones = group.zoneDurations.map { .init(id: $0.zone.index, seconds: $0.duration) }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                   from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor [weak self] in
            if toState == .ended { self?.connection.workoutChannel.disconnected(workoutSession) }
            guard let self, self.session === workoutSession else { return }
            if toState == .stopped { await self.saveHealthWorkout() }
            if toState == .paused, self.archive.current?.isActive == true, self.archive.current?.pausedAt == nil {
                self.archive.current?.togglePause(at: date); try? self.persist(); self.publish(durable: true)
            }
            if toState == .running, self.archive.current?.pausedAt != nil {
                self.archive.current?.togglePause(at: date); try? self.persist(); self.publish(durable: true)
            }
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.connection.workoutChannel.disconnected(workoutSession)
            guard let self, self.session === workoutSession else { return }
            self.timer?.cancel()
            self.archive.current?.finish(effort: nil, at: .now)
            self.archive.current?.healthSaveError = error.localizedDescription
            try? self.persist(); self.publish(durable: true)
            self.isBusy = false; self.fail(error.localizedDescription)
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]) {
        Task { @MainActor [weak self] in self?.connection.workoutChannel.receive(data, from: workoutSession) }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: Error?) {
        Task { @MainActor [weak self] in self?.connection.workoutChannel.disconnected(workoutSession) }
    }
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor [weak self] in
            guard self?.builder === workoutBuilder else { return }
            self?.updateMetrics()
        }
    }
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didUpdateWorkoutZone zoneUpdate: HKLiveWorkoutZoneUpdate) {
        Task { @MainActor [weak self] in
            guard self?.builder === workoutBuilder, zoneUpdate.zoneGroup?.configuration.quantityType == HKQuantityType(.heartRate) else { return }
            self?.archive.current?.metrics.currentZone = zoneUpdate.currentZoneDuration?.zone.index
            self?.updateZones(zoneUpdate.zoneGroup)
        }
    }
}
