import XCTest
@testable import Workoutes

@MainActor
final class TrainingStartReadinessTests: XCTestCase {
    func testColdStartWaitsForActivationBeforeAcceptingTheWatch() async throws {
        var activated = false
        var state = TrainingStartReadiness.State.activating
        var waits = 0
        try await TrainingStartReadiness.prepare(activate: { activated = true }, state: {
            XCTAssertTrue(activated)
            return state
        }, attempts: 3, wait: {
            waits += 1
            state = .ready
        })
        XCTAssertEqual(waits, 1)
    }

    func testPairingAndInstallationMetadataCanCatchUpAfterActivation() async throws {
        var state = TrainingStartReadiness.State.activating
        var waits = 0
        try await TrainingStartReadiness.prepare(activate: {}, state: { state }, attempts: 4, wait: {
            waits += 1
            switch waits {
            case 1: state = .unpaired
            case 2: state = .appNotInstalled
            default: state = .ready
            }
        })
        XCTAssertEqual(waits, 3)
    }

    func testInstalledWatchIsReadyWithoutWaitingForALiveWorkoutChannel() async throws {
        try await TrainingStartReadiness.prepare(activate: {}, state: { .ready }, wait: {
            XCTFail("An activated and installed watch can be woken by HealthKit without live messaging")
        })
    }

    func testTimeoutDistinguishesActivationFromMissingPairingOrInstallation() async throws {
        for state in [TrainingStartReadiness.State.activating, .unpaired, .appNotInstalled] {
            do {
                try await TrainingStartReadiness.prepare(activate: {}, state: { state }, attempts: 2, wait: {})
                XCTFail("An unavailable watch must not be accepted")
            } catch let error as TrainingStartReadiness.Failure {
                switch (state, error) {
                case (.activating, .activationTimedOut), (.unpaired, .unpaired), (.appNotInstalled, .appNotInstalled): break
                default: XCTFail("The error must report the actual connection state")
                }
            }
        }
    }

    func testActivationAtTheTimeoutBoundaryStillAllowsStarting() async throws {
        var state = TrainingStartReadiness.State.activating
        try await TrainingStartReadiness.prepare(activate: {}, state: { state }, attempts: 1, wait: {
            state = .ready
        })
    }

    func testCancellationDoesNotReportThatTheWatchAppIsMissing() async throws {
        do {
            try await TrainingStartReadiness.prepare(activate: {}, state: { .activating }, wait: {
                throw CancellationError()
            })
            XCTFail("Cancelled activation must stop waiting")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }
}
