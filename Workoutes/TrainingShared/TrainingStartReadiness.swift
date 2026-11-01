import Foundation

/// Installation and pairing flags are undefined until WatchConnectivity activates.
@MainActor
enum TrainingStartReadiness {
    enum State { case activating, unpaired, appNotInstalled, ready }

    enum Failure: LocalizedError {
        case activationTimedOut, unpaired, appNotInstalled

        var errorDescription: String? {
            switch self {
            case .activationTimedOut: String(localized: "Couldn't activate the Apple Watch connection. Try starting training again.")
            case .unpaired: String(localized: "No paired Apple Watch is available for this iPhone.")
            case .appNotInstalled: String(localized: "Workoutes isn't installed on the Apple Watch currently paired with this iPhone.")
            }
        }
    }

    static func prepare(activate: () -> Void, state: () -> State,
                        attempts: Int = 50,
                        wait: () async throws -> Void = { try await Task.sleep(for: .milliseconds(200)) }) async throws {
        activate()
        // Pairing/install metadata can arrive just after the activation callback.
        for _ in 0..<attempts {
            try Task.checkCancellation()
            if state() == .ready { return }
            try await wait()
        }
        try Task.checkCancellation()
        switch state() {
        case .ready: return
        case .activating: throw Failure.activationTimedOut
        case .unpaired: throw Failure.unpaired
        case .appNotInstalled: throw Failure.appNotInstalled
        }
    }
}
