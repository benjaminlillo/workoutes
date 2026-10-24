import Foundation

/// Evaluate availability at delivery time and retry the SAME envelope on the other live channel.
/// Nothing is queued for a later workout stage; existing command IDs/revisions protect ambiguous retries.
@MainActor
struct TrainingLiveRoute {
    var isAvailable: () -> Bool
    var send: (Data) async throws -> Void

    static func deliver(_ data: Data, preferred: Self, fallback: Self) async throws {
        if preferred.isAvailable() {
            do { try await preferred.send(data); return }
            catch {
                guard fallback.isAvailable() else { throw TrainingFailure.notConnected }
            }
        }
        guard fallback.isAvailable() else { throw TrainingFailure.notConnected }
        try await fallback.send(data)
    }
}
