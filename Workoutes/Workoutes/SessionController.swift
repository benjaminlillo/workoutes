import ActivityKit
import Foundation
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class SessionController {
    private let container: ModelContainer
    private let context: ModelContext
    private let exerciseController: ExerciseActivityController
    private let liveActivitiesEnabled: Bool
    private let notificationsEnabled: Bool
    private var activity: Activity<SessionActivityAttributes>?
    private var restTask: Task<Void, Never>?
    private var isForeground = true
    private var isMutating = false

    private(set) var activeSession: TrainingSession?
    private(set) var isUpdating = false
    private(set) var presentationRevision = 0
    var errorMessage: String?
    var notificationsUnavailable = false

    init(
        container: ModelContainer,
        exerciseController: ExerciseActivityController,
        liveActivitiesEnabled: Bool = true,
        notificationsEnabled: Bool = true
    ) {
        self.container = container
        context = container.mainContext
        self.exerciseController = exerciseController
        self.liveActivitiesEnabled = liveActivitiesEnabled
        self.notificationsEnabled = notificationsEnabled
        ensureDefaultTemplate()
        restore()
    }

    var isActive: Bool { activeSession != nil && activeSession?.endedAt == nil }

    var currentBlock: SessionBlockRecord? {
        activeSession?.blocks
            .filter { $0.startedAt != nil && $0.endedAt == nil }
            .sorted { $0.order < $1.order }
            .first
    }

    var currentContent: SessionActivityAttributes.ContentState? {
        _ = presentationRevision
        guard let session = activeSession, let block = currentBlock else { return nil }
        return makeContent(session: session, block: block)
    }

    func ensureDefaultTemplate() {
        var templates = (try? context.fetch(FetchDescriptor<SessionTemplate>())) ?? []
        if templates.isEmpty {
            let template = SessionTemplate(name: "Flexible Session")
            let definitions: [(SessionBlockKind, String, TimeInterval)] = [
                (.exercise, "Exercise", 60), (.rest, "Rest", 60),
                (.exercise, "Exercise", 60), (.rest, "Rest", 60),
                (.exercise, "Exercise", 60)
            ]
            template.blocks = definitions.enumerated().map { index, definition in
                SessionTemplateBlock(order: index, name: definition.1, kind: definition.0, restDuration: definition.2)
            }
            context.insert(template)
            templates = [template]
        }

        var changed = false
        for block in templates.flatMap(\.blocks) where block.kind == .exercise && !Self.validRestDuration(block.restDuration) {
            block.restDuration = 60
            changed = true
        }
        if changed || context.hasChanges { save() }
    }

    func start() {
        guard !isActive, !isMutating else { return }
        ensureDefaultTemplate()
        guard let template = try? context.fetch(FetchDescriptor<SessionTemplate>()).first else {
            errorMessage = "The session template could not be loaded."
            return
        }
        let definitions = template.blocks.sorted { $0.order < $1.order }
        guard !definitions.isEmpty else {
            errorMessage = "Add at least one block before starting a session."
            return
        }

        isMutating = true
        let now = Date()
        let session = TrainingSession(templateName: template.name, startedAt: now)
        session.templateSnapshot = definitions.map(SessionTemplateSnapshotBlock.init)
        session.blocks = definitions.enumerated().map { index, block in
            SessionBlockRecord(
                order: index,
                configuredName: block.name,
                kind: block.kind,
                plannedRestDuration: normalizedDuration(for: block),
                sourceTemplateBlockID: block.id
            )
        }
        session.blocks.first?.startedAt = now
        context.insert(session)
        activeSession = session
        expandCurrentExerciseIfNeeded(at: now)
        save()
        isMutating = false
        Task { await beginLivePresentation() }
        scheduleCurrentRest()
    }

    func requestStop() {
        stopEarly()
    }

    func stopEarly() {
        guard !isMutating, let session = activeSession, let block = currentBlock else { return }
        isMutating = true
        let now = Date()
        block.resolvedName = displayedName(for: block)
        block.endedAt = now
        if block.kind == .exercise || block.isExerciseGroupBlock {
            exerciseController.deactivateActive(context: context)
        }
        session.endedEarly = true
        session.endedAt = now
        SessionNotificationManager.shared.cancel(blockID: block.id)
        restTask?.cancel()
        save()
        let final = makeContent(session: session, block: block, ended: true)
        activeSession = nil
        isMutating = false
        Task { await endLivePresentation(final: final) }
    }

    func advance(expectedSessionID: UUID? = nil, expectedBlockID: UUID? = nil) {
        guard !isMutating, let session = activeSession, var block = currentBlock else { return }
        guard expectedSessionID == nil || expectedSessionID == session.id,
              expectedBlockID == nil || expectedBlockID == block.id else { return }

        if block.kind == .exercise, !block.isExerciseGroupBlock,
           exerciseController.activeExercise(in: context) != nil {
            isMutating = true
            expandCurrentExerciseIfNeeded(at: block.startedAt ?? Date())
            save()
            isMutating = false
            block = currentBlock ?? block
        }

        isMutating = true
        let now = Date()
        end(block, at: now)

        if block.isExerciseGroupBlock, let setIndex = block.setIndex, let setCount = block.setCount,
           setIndex == setCount {
            completeBoundExercise(for: block)
        } else if block.kind == .exercise, !block.isExerciseGroupBlock {
            exerciseController.completeActive(context: context)
        }

        moveToNextBlock(after: block, at: now, in: session)
    }

    /// Reconciles the session timeline after an exercise is activated, completed, switched, or deleted.
    func reconcileActiveExercise() {
        guard !isMutating else { return }
        guard let session = activeSession, let block = currentBlock else {
            refreshPresentation()
            return
        }

        let activeExercise = exerciseController.activeExercise(in: context)
        if block.isExerciseGroupBlock {
            if let activeExercise {
                if exerciseIdentifier(for: block) == activeExercise.persistentModelID {
                    refreshPresentation()
                } else {
                    switchExerciseGroup(from: block, to: activeExercise, in: session)
                }
            } else if boundExercise(for: block) != nil {
                finishCurrentGroupAfterManualCompletion(block, in: session)
            } else {
                // A deleted exercise has no model to update, but its frozen group can still finish.
                refreshPresentation()
            }
        } else if block.kind == .exercise, activeExercise != nil {
            isMutating = true
            expandCurrentExerciseIfNeeded(at: block.startedAt ?? Date())
            save()
            isMutating = false
            refreshPresentation()
            scheduleCurrentRest()
        } else {
            // Selecting an exercise during an original rest prepares it for the next exercise block.
            refreshPresentation()
        }
    }

    func setSceneActive(_ active: Bool) {
        isForeground = active
        if active {
            reconcileExpiredRest()
            reconcileActiveExercise()
            scheduleCurrentRest()
        } else {
            restTask?.cancel()
        }
    }

    func refreshPresentation() {
        presentationRevision &+= 1
        guard let content = currentContent else { return }
        Task { await updateLivePresentation(content) }
    }

    func restore() {
        let sessions = (try? context.fetch(FetchDescriptor<TrainingSession>())) ?? []
        activeSession = sessions
            .filter { $0.endedAt == nil }
            .sorted { $0.startedAt > $1.startedAt }
            .first
        activity = Activity<SessionActivityAttributes>.activities.first
        for duplicate in Activity<SessionActivityAttributes>.activities.dropFirst() {
            Task { await duplicate.end(nil, dismissalPolicy: .immediate) }
        }
        guard activeSession != nil else {
            for orphan in Activity<SessionActivityAttributes>.activities {
                Task { await orphan.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }
        reconcileExpiredRest()
        reconcileActiveExercise()
        if activity == nil { Task { await beginLivePresentation() } }
        else { refreshPresentation() }
        scheduleCurrentRest()
    }

    private func switchExerciseGroup(
        from block: SessionBlockRecord,
        to exercise: WorkoutExercise,
        in session: TrainingSession
    ) {
        isMutating = true
        let now = Date()
        if let previous = boundExercise(for: block) {
            exerciseController.complete(previous, context: context)
        }
        end(block, at: now)
        removePendingBlocks(inGroup: block.exerciseGroupID, from: session)

        let replacement = SessionBlockRecord(
            order: block.order + 1,
            configuredName: block.configuredName,
            kind: .exercise,
            plannedRestDuration: normalizedExerciseRest(block.plannedRestDuration),
            sourceTemplateBlockID: block.sourceTemplateBlockID
        )
        replacement.startedAt = now
        insert([replacement], after: block, in: session)
        expand(replacement, for: exercise)
        save()
        isMutating = false
        refreshPresentation()
        scheduleCurrentRest()
    }

    private func finishCurrentGroupAfterManualCompletion(
        _ block: SessionBlockRecord,
        in session: TrainingSession
    ) {
        isMutating = true
        let now = Date()
        end(block, at: now)
        removePendingBlocks(inGroup: block.exerciseGroupID, from: session)
        moveToNextBlock(after: block, at: now, in: session)
    }

    private func moveToNextBlock(after block: SessionBlockRecord, at date: Date, in session: TrainingSession) {
        let ordered = orderedBlocks(in: session)
        if let index = ordered.firstIndex(where: { $0.id == block.id }), index + 1 < ordered.count {
            ordered[index + 1].startedAt = date
            expandCurrentExerciseIfNeeded(at: date)
            save()
            isMutating = false
            refreshPresentation()
            scheduleCurrentRest()
        } else {
            finish(session, after: block, at: date)
        }
    }

    private func finish(_ session: TrainingSession, after block: SessionBlockRecord, at date: Date) {
        session.endedEarly = false
        session.endedAt = date
        save()
        let final = makeContent(session: session, block: block, ended: true)
        activeSession = nil
        isMutating = false
        Task { await endLivePresentation(final: final) }
    }

    private func end(_ block: SessionBlockRecord, at date: Date) {
        block.resolvedName = displayedName(for: block)
        block.endedAt = date
        SessionNotificationManager.shared.cancel(blockID: block.id)
        restTask?.cancel()
    }

    private func expandCurrentExerciseIfNeeded(at date: Date) {
        guard let block = currentBlock, block.kind == .exercise, !block.isExerciseGroupBlock,
              let exercise = exerciseController.activeExercise(in: context) else { return }
        if block.startedAt == nil { block.startedAt = date }
        expand(block, for: exercise)
    }

    private func expand(_ firstSet: SessionBlockRecord, for exercise: WorkoutExercise) {
        guard let session = activeSession, !firstSet.isExerciseGroupBlock else { return }
        let setCount = max(1, exercise.numberOfSets)
        let groupID = UUID()
        let identifierData = try? JSONEncoder().encode(exercise.persistentModelID)
        let title = exercise.title
        let restDuration = normalizedExerciseRest(firstSet.plannedRestDuration)

        applyGroupMetadata(
            to: firstSet, groupID: groupID, exerciseID: identifierData,
            title: title, setIndex: 1, setCount: setCount
        )

        guard setCount > 1 else { return }
        var generated: [SessionBlockRecord] = []
        for index in 2...setCount {
            let rest = SessionBlockRecord(
                order: 0,
                configuredName: "Rest",
                kind: .rest,
                plannedRestDuration: restDuration,
                sourceTemplateBlockID: firstSet.sourceTemplateBlockID
            )
            rest.exerciseGroupID = groupID
            rest.exerciseIdentifierData = identifierData
            rest.exerciseTitle = title
            rest.setCount = setCount
            rest.isInterSetRestValue = true
            generated.append(rest)

            let set = SessionBlockRecord(
                order: 0,
                configuredName: firstSet.configuredName,
                kind: .exercise,
                plannedRestDuration: restDuration,
                sourceTemplateBlockID: firstSet.sourceTemplateBlockID
            )
            applyGroupMetadata(
                to: set, groupID: groupID, exerciseID: identifierData,
                title: title, setIndex: index, setCount: setCount
            )
            generated.append(set)
        }
        insert(generated, after: firstSet, in: session)
    }

    private func applyGroupMetadata(
        to block: SessionBlockRecord,
        groupID: UUID,
        exerciseID: Data?,
        title: String,
        setIndex: Int,
        setCount: Int
    ) {
        block.exerciseGroupID = groupID
        block.exerciseIdentifierData = exerciseID
        block.exerciseTitle = title
        block.setIndex = setIndex
        block.setCount = setCount
        block.isInterSetRestValue = false
    }

    private func insert(_ newBlocks: [SessionBlockRecord], after block: SessionBlockRecord, in session: TrainingSession) {
        guard !newBlocks.isEmpty else { return }
        var ordered = orderedBlocks(in: session)
        let index = ordered.firstIndex(where: { $0.id == block.id }) ?? max(0, ordered.count - 1)
        ordered.insert(contentsOf: newBlocks, at: min(index + 1, ordered.count))
        for (order, item) in ordered.enumerated() { item.order = order }
        session.blocks = ordered
    }

    private func removePendingBlocks(inGroup groupID: UUID?, from session: TrainingSession) {
        guard let groupID else { return }
        let pending = session.blocks.filter { $0.exerciseGroupID == groupID && $0.startedAt == nil }
        guard !pending.isEmpty else { return }
        session.blocks.removeAll { candidate in pending.contains { $0.id == candidate.id } }
        for block in pending { context.delete(block) }
        for (order, block) in orderedBlocks(in: session).enumerated() { block.order = order }
    }

    private func completeBoundExercise(for block: SessionBlockRecord) {
        guard let exercise = boundExercise(for: block) else { return }
        exerciseController.complete(exercise, context: context)
    }

    private func boundExercise(for block: SessionBlockRecord) -> WorkoutExercise? {
        guard let identifier = exerciseIdentifier(for: block) else { return nil }
        let exercises = (try? context.fetch(FetchDescriptor<WorkoutExercise>())) ?? []
        return exercises.first { $0.persistentModelID == identifier && !$0.isDeleted }
    }

    private func exerciseIdentifier(for block: SessionBlockRecord) -> PersistentIdentifier? {
        guard let data = block.exerciseIdentifierData else { return nil }
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }

    private func orderedBlocks(in session: TrainingSession) -> [SessionBlockRecord] {
        session.blocks.sorted { $0.order < $1.order }
    }

    private func reconcileExpiredRest() {
        guard isForeground, let block = currentBlock, block.kind == .rest,
              let startedAt = block.startedAt,
              Date() >= startedAt.addingTimeInterval(block.plannedRestDuration) else { return }
        advance(expectedSessionID: activeSession?.id, expectedBlockID: block.id)
    }

    private func scheduleCurrentRest() {
        restTask?.cancel()
        guard let session = activeSession, let block = currentBlock,
              block.kind == .rest, let startedAt = block.startedAt else { return }
        let end = startedAt.addingTimeInterval(block.plannedRestDuration)
        if notificationsEnabled {
            Task {
                let allowed = await SessionNotificationManager.shared.scheduleRestEnd(
                    sessionID: session.id, blockID: block.id, blockName: displayedName(for: block), at: end
                )
                if !allowed { notificationsUnavailable = true }
            }
        }
        guard isForeground else { return }
        let sessionID = session.id
        let blockID = block.id
        restTask = Task { @MainActor [weak self] in
            let delay = max(0, end.timeIntervalSinceNow)
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            catch { return }
            self?.advance(expectedSessionID: sessionID, expectedBlockID: blockID)
        }
    }

    private func displayedName(for block: SessionBlockRecord) -> String {
        if block.isInterSetRest, let title = block.exerciseTitle {
            return "\(title) · Rest"
        }
        if let setIndex = block.setIndex, let setCount = block.setCount, let title = block.exerciseTitle {
            return "\(title) · \(setIndex)/\(setCount)"
        }
        guard block.kind == .exercise,
              let exercise = exerciseController.activeExercise(in: context) else { return block.configuredName }
        return exercise.title
    }

    private func makeContent(
        session: TrainingSession,
        block: SessionBlockRecord,
        ended: Bool = false
    ) -> SessionActivityAttributes.ContentState {
        let ordered = orderedBlocks(in: session)
        let index = ordered.firstIndex(where: { $0.id == block.id }) ?? 0
        let start = block.startedAt ?? session.startedAt
        return SessionActivityAttributes.ContentState(
            sessionID: session.id.uuidString,
            blockID: block.id.uuidString,
            blockName: displayedName(for: block),
            blockKind: block.kind == .exercise ? .exercise : .rest,
            blockStartedAt: start,
            sessionStartedAt: session.startedAt,
            restEndsAt: block.kind == .rest ? start.addingTimeInterval(block.plannedRestDuration) : nil,
            currentIndex: index,
            totalBlocks: ordered.count,
            isLastBlock: index == ordered.count - 1,
            accentColorHex: UserDefaults.standard.string(forKey: "appAccentColor") ?? ThemeColor.primary.rawValue,
            ended: ended
        )
    }

    private func normalizedDuration(for block: SessionTemplateBlock) -> TimeInterval {
        block.kind == .exercise ? normalizedExerciseRest(block.restDuration) : block.restDuration
    }

    private func normalizedExerciseRest(_ duration: TimeInterval) -> TimeInterval {
        Self.validRestDuration(duration) ? duration : 60
    }

    private static func validRestDuration(_ duration: TimeInterval) -> Bool {
        duration >= 5 && duration <= 3600
    }

    private func beginLivePresentation() async {
        guard liveActivitiesEnabled, let content = currentContent,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            isUpdating = true
            activity = try Activity.request(
                attributes: SessionActivityAttributes(),
                content: ActivityContent(state: content, staleDate: content.restEndsAt),
                pushType: nil
            )
            isUpdating = false
        } catch {
            isUpdating = false
            errorMessage = "The Live Activity could not be started: \(error.localizedDescription)"
        }
    }

    private func updateLivePresentation(_ content: SessionActivityAttributes.ContentState) async {
        guard liveActivitiesEnabled else { return }
        await activity?.update(ActivityContent(state: content, staleDate: content.restEndsAt))
    }

    private func endLivePresentation(final: SessionActivityAttributes.ContentState) async {
        guard liveActivitiesEnabled else { return }
        await activity?.end(
            ActivityContent(state: final, staleDate: nil),
            dismissalPolicy: .after(Date().addingTimeInterval(2))
        )
        activity = nil
    }

    private func save() {
        do { try context.save() }
        catch { errorMessage = "The session could not be saved: \(error.localizedDescription)" }
    }
}
