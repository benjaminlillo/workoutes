import Foundation
import XCTest
@testable import Workoutes

@MainActor
final class TrainingLiveRouteTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_790_000_000)
    private func exercise() -> TrainingExercise {
        .init(id: "bench", name: "Bench Press", weightKilograms: 40, repetitions: 8, sets: 3, usesPounds: false)
    }

    func testLiveWorkoutChannelDeliversSelectionWhenWatchConnectivityIsUnreachable() async throws {
        let run = try TrainingRun(plan: .daily, at: origin)
        let command = TrainingCommand(action: .selectExercise, runID: run.id, revision: run.revision,
                                      exercise: exercise())
        let payload = try JSONEncoder().encode(TrainingEnvelope(kind: .command, command: command))
        var received: [Data] = []
        var fallbackCalls = 0
        try await TrainingLiveRoute.deliver(payload,
            preferred: .init(isAvailable: { true }, send: { received.append($0) }),
            fallback: .init(isAvailable: { false }, send: { _ in fallbackCalls += 1 }))
        let delivered = try XCTUnwrap(JSONDecoder().decode(TrainingEnvelope.self, from: XCTUnwrap(received.first)).command)
        XCTAssertEqual(delivered.id, command.id)
        XCTAssertEqual(delivered.runID, run.id)
        XCTAssertEqual(delivered.exercise, exercise())
        XCTAssertEqual(fallbackCalls, 0)
    }

    func testInterruptedWorkoutChannelRetriesIdenticalCommandOnWatchConnectivity() async throws {
        let command = TrainingCommand(action: .advance, runID: UUID(), revision: 4)
        let payload = try JSONEncoder().encode(TrainingEnvelope(kind: .command, command: command))
        var attempted: [Data] = []
        var fallbackAvailable = false
        try await TrainingLiveRoute.deliver(payload,
            preferred: .init(isAvailable: { true }, send: {
                attempted.append($0)
                fallbackAvailable = true
                throw TrainingFailure.notConnected
            }),
            fallback: .init(isAvailable: { fallbackAvailable }, send: { attempted.append($0) }))
        XCTAssertEqual(attempted, [payload, payload])
        let retried = try XCTUnwrap(JSONDecoder().decode(TrainingEnvelope.self, from: attempted[1]).command)
        // Retain the command identity, expected revision and expiry when retrying an ambiguous delivery.
        XCTAssertEqual(retried.id, command.id)
        XCTAssertEqual(retried.revision, 4)
        XCTAssertEqual(retried.createdAt, command.createdAt)
    }

    func testWatchConnectivityStillDeliversWithoutMirroredWorkoutIncludingSimulatorPreviews() async throws {
        let payload = Data("snapshot".utf8)
        var delivered: [Data] = []
        try await TrainingLiveRoute.deliver(payload,
            preferred: .init(isAvailable: { false }, send: { _ in XCTFail("No mirrored workout") }),
            fallback: .init(isAvailable: { true }, send: { delivered.append($0) }))
        XCTAssertEqual(delivered, [payload])
    }

    func testLosingBothLiveChannelsFailsWithoutQueueingAnAction() async throws {
        var sends = 0
        let unavailable = TrainingLiveRoute(isAvailable: { false }, send: { _ in sends += 1 })
        do {
            try await TrainingLiveRoute.deliver(Data(), preferred: unavailable, fallback: unavailable)
            XCTFail("A disconnected action must fail")
        } catch {
            XCTAssertEqual(error.localizedDescription, TrainingFailure.notConnected.localizedDescription)
        }
        XCTAssertEqual(sends, 0)
        do {
            try await TrainingLiveRoute.deliver(Data(),
                preferred: .init(isAvailable: { true }, send: { _ in throw TrainingFailure.notConnected }),
                fallback: unavailable)
            XCTFail("A lost connection must fail")
        } catch {
            XCTAssertEqual(error.localizedDescription, TrainingFailure.notConnected.localizedDescription)
        }
        XCTAssertEqual(sends, 0)
    }

}
