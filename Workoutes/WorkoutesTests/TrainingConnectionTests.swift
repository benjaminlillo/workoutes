import WatchConnectivity
import XCTest
@testable import Workoutes

@MainActor
final class TrainingConnectionTests: XCTestCase {
    func testActivationTriggersStatePublicationWithoutWaitingForLiveReachability() async {
        let connection = TrainingConnection()
        let activated = expectation(description: "Republish persisted state after activation")
        connection.onActivation = { activated.fulfill() }
        // A fresh connection may have already attempted publication while inactive.
        connection.session(WCSession.default, activationDidCompleteWith: .activated, error: nil)
        await fulfillment(of: [activated], timeout: 1)
    }

    func testRepeatedReachabilityCallbacksDoNotRequestSnapshotsAgain() async {
        let connection = TrainingConnection()
        var notifications = 0
        connection.onReachability = { _ in notifications += 1 }
        let activated = expectation(description: "Delegate callbacks processed")
        connection.onActivation = { activated.fulfill() }
        connection.sessionReachabilityDidChange(WCSession.default)
        connection.sessionReachabilityDidChange(WCSession.default)
        connection.session(WCSession.default, activationDidCompleteWith: .activated, error: nil)
        await fulfillment(of: [activated], timeout: 1)
        XCTAssertEqual(notifications, 1)
    }
}
