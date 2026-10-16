import Foundation
import HealthKit

/// The live workout has its own bidirectional connection, independent of WCSession reachability.
@MainActor
final class TrainingWorkoutChannel: NSObject, HKWorkoutSessionDelegate {
    var onReceive: ((TrainingEnvelope) -> Void)?
    var onAvailability: (() -> Void)?
    private var session: HKWorkoutSession?
    private(set) var isReachable = false
    private var isStartingMirroring = false
    private var lastMirroringAttempt = Date.distantPast

    #if os(iOS)
    func listen(using healthStore: HKHealthStore) {
        healthStore.workoutSessionMirroringStartHandler = { [weak self] session in
            Task { @MainActor [weak self] in self?.attach(session, mirrored: true) }
        }
    }
    #endif

    func attach(_ session: HKWorkoutSession, mirrored: Bool = false) {
        guard self.session !== session else { return }
        self.session = session
        lastMirroringAttempt = .distantPast
        isStartingMirroring = false
        // The watch controller remains the delegate of its recording session.
        if mirrored { session.delegate = self }
        isReachable = mirrored
        onAvailability?()
    }

    #if os(watchOS)
    func reconnect() async {
        guard let session, session.state != .ended, !isReachable, !isStartingMirroring,
              Date.now.timeIntervalSince(lastMirroringAttempt) >= 10 else { return }
        lastMirroringAttempt = .now
        isStartingMirroring = true
        defer { isStartingMirroring = false }
        do {
            try await session.startMirroringToCompanionDevice()
            guard self.session === session, session.state != .ended else { return }
            isReachable = true
            onAvailability?()
        } catch {
            // The recording continues. Foreground entry and the workout timer retry the connection.
        }
    }
    #endif

    func send(_ data: Data) async throws {
        guard let session, isReachable, session.state != .ended else { throw TrainingFailure.notConnected }
        // A rate-limit error doesn't invalidate the session; its disconnect delegate does.
        try await session.sendToRemoteWorkoutSession(data: data)
    }

    func receive(_ data: [Data], from session: HKWorkoutSession) {
        guard self.session === session, session.state != .ended else { return }
        if !isReachable { isReachable = true; onAvailability?() }
        for item in data where item.count < 1_000_000 {
            if let envelope = try? JSONDecoder().decode(TrainingEnvelope.self, from: item) {
                onReceive?(envelope)
            }
        }
    }

    func disconnected(_ session: HKWorkoutSession) {
        guard self.session === session else { return }
        isReachable = false
        #if os(iOS)
        // HealthKit says a disconnected mirrored session is no longer valid.
        self.session = nil
        #endif
        onAvailability?()
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                   from fromState: HKWorkoutSessionState, date: Date) {
        guard toState == .ended else { return }
        Task { @MainActor [weak self] in self?.disconnected(workoutSession) }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.disconnected(workoutSession) }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]) {
        Task { @MainActor [weak self] in self?.receive(data, from: workoutSession) }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: Error?) {
        Task { @MainActor [weak self] in self?.disconnected(workoutSession) }
    }
}
