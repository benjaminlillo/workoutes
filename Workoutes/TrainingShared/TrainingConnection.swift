import Foundation
import WatchConnectivity

@MainActor
final class TrainingConnection: NSObject, WCSessionDelegate {
    var onReceive: ((TrainingEnvelope) -> Void)?
    var onReachability: ((Bool) -> Void)?
    var onError: ((String) -> Void)?
    let workoutChannel = TrainingWorkoutChannel()
    private var session: WCSession? { WCSession.isSupported() ? .default : nil }
    var isReachable: Bool { workoutChannel.isReachable || isWatchConnectivityReachable }
    private var isWatchConnectivityReachable: Bool { session?.activationState == .activated && session?.isReachable == true }
    var isWatchInstalled: Bool {
        #if os(iOS)
        session?.activationState == .activated && session?.isPaired == true && session?.isWatchAppInstalled == true
        #else
        true
        #endif
    }

    func activate() {
        workoutChannel.onReceive = { [weak self] in self?.onReceive?($0) }
        workoutChannel.onAvailability = { [weak self] in
            guard let self else { return }
            self.onReachability?(self.isReachable)
        }
        session?.delegate = self
        session?.activate()
        onReachability?(isReachable)
    }
    func refresh() {
        if session?.activationState != .activated || session?.delegate !== self { activate() }
        onReachability?(isReachable)
        if let context = receivedContext() { onReceive?(context) }
    }
    #if os(iOS)
    func prepareForWorkoutStart() async throws {
        try await TrainingStartReadiness.prepare(activate: { self.refresh() }, state: {
            guard let session = self.session, session.activationState == .activated else { return .activating }
            guard session.isPaired else { return .unpaired }
            // A live counterpart is also evidence of installation while its metadata catches up.
            return session.isWatchAppInstalled || session.isReachable ? .ready : .appNotInstalled
        })
    }
    #endif
    func publish(_ envelope: TrainingEnvelope, durable: Bool = false, replacesContext: Bool = true) throws {
        let data = try JSONEncoder().encode(envelope)
        var contextError: Error?
        if let session, session.activationState == .activated {
            let payload = ["training": data]
            if replacesContext {
                do { try session.updateApplicationContext(payload) } catch { contextError = error }
            }
            if durable { session.transferUserInfo(payload) }
        } else if !isReachable { throw TrainingFailure.notConnected }
        if isReachable { deliver(data) }
        else if let contextError { throw contextError }
    }
    private func deliver(_ data: Data, allowsWorkoutChannel: Bool = true) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await TrainingLiveRoute.deliver(data,
                    preferred: .init(isAvailable: { allowsWorkoutChannel && self.workoutChannel.isReachable },
                                     send: { try await self.workoutChannel.send($0) }),
                    fallback: .init(isAvailable: { self.isWatchConnectivityReachable },
                                    send: { try await self.sendWatchConnectivity($0) }))
            } catch { self.onError?(error.localizedDescription) }
        }
    }
    private func sendWatchConnectivity(_ data: Data) async throws {
        guard let session, isWatchConnectivityReachable else { throw TrainingFailure.notConnected }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.sendMessage(["training": data], replyHandler: { _ in continuation.resume() },
                                errorHandler: { continuation.resume(throwing: $0) })
        }
    }
    // Interactive commands are never queued for a later stage of the workout.
    func send(_ envelope: TrainingEnvelope, allowsWorkoutChannel: Bool = true) throws {
        guard (allowsWorkoutChannel && workoutChannel.isReachable) || isWatchConnectivityReachable else {
            throw TrainingFailure.notConnected
        }
        deliver(try JSONEncoder().encode(envelope), allowsWorkoutChannel: allowsWorkoutChannel)
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
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        receive(message)
        replyHandler([:])
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { receive(applicationContext) }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) { receive(userInfo) }
    #if os(iOS)
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.refresh() }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.onReachability?(self.isReachable)
        }
    }
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.activate() }
    }
    #else
    nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.refresh() }
    }
    #endif
}
