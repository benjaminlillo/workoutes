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
        guard ((try? context.fetchCount(FetchDescriptor<SessionTemplate>())) ?? 0) == 0 else { return }
        let template = SessionTemplate(name: "Flexible Session")
        let definitions: [(SessionBlockKind, String, TimeInterval)] = [
            (.exercise, "Exercise", 0), (.rest, "Rest", 60),
            (.exercise, "Exercise", 0), (.rest, "Rest", 60),
            (.exercise, "Exercise", 0)
        ]
        template.blocks = definitions.enumerated().map { index, definition in
            SessionTemplateBlock(order: index, name: definition.1, kind: definition.0, restDuration: definition.2)
        }
        context.insert(template)
        save()
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
        session.blocks = definitions.enumerated().map { index, block in
            SessionBlockRecord(
                order: index,
                configuredName: block.name,
                kind: block.kind,
                plannedRestDuration: block.restDuration
            )
        }
        session.blocks.first?.startedAt = now
        context.insert(session)
        activeSession = session
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
        if block.kind == .exercise { exerciseController.deactivateActive(context: context) }
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
        guard !isMutating, let session = activeSession, let block = currentBlock else { return }
        guard expectedSessionID == nil || expectedSessionID == session.id,
              expectedBlockID == nil || expectedBlockID == block.id else { return }
        isMutating = true
        let now = Date()
        block.resolvedName = displayedName(for: block)
        block.endedAt = now
        SessionNotificationManager.shared.cancel(blockID: block.id)
        restTask?.cancel()

        if block.kind == .exercise { exerciseController.completeActive(context: context) }
        let ordered = session.blocks.sorted { $0.order < $1.order }
        if let index = ordered.firstIndex(where: { $0.id == block.id }), index + 1 < ordered.count {
            ordered[index + 1].startedAt = now
            save()
            isMutating = false
            refreshPresentation()
            scheduleCurrentRest()
        } else {
            session.endedEarly = false
            session.endedAt = now
            save()
            let final = makeContent(session: session, block: block, ended: true)
            activeSession = nil
            isMutating = false
            Task { await endLivePresentation(final: final) }
        }
    }

    func setSceneActive(_ active: Bool) {
        isForeground = active
        if active {
            reconcileExpiredRest()
            refreshPresentation()
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
        if activity == nil { Task { await beginLivePresentation() } }
        else { refreshPresentation() }
        scheduleCurrentRest()
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
        guard block.kind == .exercise,
              let exercise = exerciseController.activeExercise(in: context) else { return block.configuredName }
        return exercise.title
    }

    private func makeContent(
        session: TrainingSession,
        block: SessionBlockRecord,
        ended: Bool = false
    ) -> SessionActivityAttributes.ContentState {
        let ordered = session.blocks.sorted { $0.order < $1.order }
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
