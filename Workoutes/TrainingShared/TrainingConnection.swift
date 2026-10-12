import Foundation
import WatchConnectivity

struct TrainingCommand: Codable, Sendable {
    enum Action: String, Codable, Sendable { case start, selectExercise, advance, pause, undo, finish, retrySave, keepLocalRecord }
    var id = UUID()
    var createdAt = Date()
    var action: Action
    var runID: UUID?
    var revision: Int?
    var plan: TrainingPlan?
    var exercise: TrainingExercise?
    var effort: Int?
}

struct TrainingEnvelope: Codable, Sendable {
    enum Kind: String, Codable, Sendable { case snapshot, command, requestSnapshot, plan, failure }
    var kind: Kind
    var sentAt = Date()
    var run: TrainingRun?
    var command: TrainingCommand?
    var plan: TrainingPlan?
    var error: String?
}

@MainActor
final class TrainingConnection: NSObject, WCSessionDelegate {
    var onReceive: ((TrainingEnvelope) -> Void)?
    var onReachability: ((Bool) -> Void)?
    var onError: ((String) -> Void)?
    private var session: WCSession? { WCSession.isSupported() ? .default : nil }
    var isReachable: Bool { session?.activationState == .activated && session?.isReachable == true }
    var isWatchInstalled: Bool {
        #if os(iOS)
        session?.activationState == .activated && session?.isPaired == true && session?.isWatchAppInstalled == true
        #else
        true
        #endif
    }

    func activate() {
        session?.delegate = self
        session?.activate()
    }
    func publish(_ envelope: TrainingEnvelope, durable: Bool = false, replacesContext: Bool = true) throws {
        guard let session, session.activationState == .activated else { throw TrainingFailure.notConnected }
        let payload = ["training": try JSONEncoder().encode(envelope)]
        if replacesContext { try session.updateApplicationContext(payload) }
        if durable { session.transferUserInfo(payload) }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in self?.onError?(error.localizedDescription) }
            }
        }
    }
    // Interactive commands are never queued for a later stage of the workout.
    func send(_ envelope: TrainingEnvelope) throws {
        guard let session, isReachable else { throw TrainingFailure.notConnected }
        session.sendMessage(["training": try JSONEncoder().encode(envelope)], replyHandler: nil) { [weak self] error in
            Task { @MainActor in self?.onError?(error.localizedDescription) }
        }
    }
    func receivedContext() -> TrainingEnvelope? {
        guard let data = session?.receivedApplicationContext["training"] as? Data else { return nil }
        return try? JSONDecoder().decode(TrainingEnvelope.self, from: data)
    }

    nonisolated private func receive(_ payload: [String: Any]) {
        guard let data = payload["training"] as? Data, data.count < 1_000_000 else { return }
        Task { @MainActor [weak self] in
            guard let envelope = try? JSONDecoder().decode(TrainingEnvelope.self, from: data) else { return }
            self?.onReceive?(envelope)
        }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in
            if let error { self?.onError?(error.localizedDescription) }
            self?.onReachability?(self?.isReachable == true)
            if let envelope = self?.receivedContext() { self?.onReceive?(envelope) }
        }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.onReachability?(self?.isReachable == true) }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { receive(message) }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { receive(applicationContext) }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) { receive(userInfo) }
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
