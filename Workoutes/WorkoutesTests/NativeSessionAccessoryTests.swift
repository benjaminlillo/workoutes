import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class NativeSessionAccessoryTests: XCTestCase {
    func testSessionAccessoryAttachesUpdatesAndRemoves() async throws {
        let state = TestState()
        let root = UIHostingController(rootView: TestTabs(state: state))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer { window.isHidden = true }

        var tabs: UITabBarController?
        for _ in 0..<100 {
            tabs = findTabs(in: root)
            if tabs != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let actualTabs = try XCTUnwrap(tabs)
        state.content = content("Exercise")
        try await Task.sleep(for: .milliseconds(200))
        let accessory = try XCTUnwrap(actualTabs.bottomAccessory)

        state.content = content("Rest")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(actualTabs.bottomAccessory === accessory)
        let host = try XCTUnwrap(actualTabs.children.compactMap { $0 as? NativeSessionAccessory.AccessoryHost }.first)
        XCTAssertEqual(host.state.content.blockName, "Rest")
        XCTAssertEqual(actualTabs.tabBarMinimizeBehavior, .onScrollDown)

        state.content = nil
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertNil(actualTabs.bottomAccessory)
        XCTAssertEqual(actualTabs.tabBarMinimizeBehavior, .never)
    }

    func testInsertionAndRemovalUseNativeAnimation() async throws {
        let tabs = RecordingTabController()
        tabs.viewControllers = [UIViewController()]
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        let bridge = NativeSessionAccessory.Controller()
        tabs.addChild(bridge)
        tabs.view.addSubview(bridge.view)
        bridge.didMove(toParent: tabs)
        defer { bridge.tearDown(); window.isHidden = true }

        bridge.configuration = configuration(content("First"))
        bridge.scheduleUpdate()
        await nextMainQueueTurn()
        let accessory = tabs.bottomAccessory
        XCTAssertNotNil(accessory)

        bridge.configuration = configuration(content("Second"))
        bridge.scheduleUpdate()
        await nextMainQueueTurn()
        XCTAssertTrue(tabs.bottomAccessory === accessory)

        bridge.configuration = configuration(nil)
        bridge.scheduleUpdate()
        await nextMainQueueTurn()
        XCTAssertNil(tabs.bottomAccessory)
        XCTAssertEqual(tabs.animationRequests, [true, true])
    }

    private func configuration(_ content: SessionActivityAttributes.ContentState?) -> NativeSessionAccessory {
        NativeSessionAccessory(content: content, isUpdating: false, accentColor: .blue, onAdvance: {})
    }

    private func content(_ name: String) -> SessionActivityAttributes.ContentState {
        .init(sessionID: "session", blockID: name, blockName: name, blockKind: .exercise,
              blockStartedAt: .now, sessionStartedAt: .now, restEndsAt: nil,
              currentIndex: 0, totalBlocks: 3, isLastBlock: false, accentColorHex: "007AFF")
    }

    private func nextMainQueueTurn() async {
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    }

    private func findTabs(in controller: UIViewController) -> UITabBarController? {
        if let tabs = controller as? UITabBarController { return tabs }
        return controller.children.compactMap { findTabs(in: $0) }.first
    }

    private final class TestState: ObservableObject {
        @Published var content: SessionActivityAttributes.ContentState?
    }

    private struct TestTabs: View {
        @ObservedObject var state: TestState
        var body: some View {
            TabView {
                Tab("First", systemImage: "1.circle") { Text("First") }
                Tab("Second", systemImage: "2.circle") { Text("Second") }
            }
            .background {
                NativeSessionAccessory(content: state.content, isUpdating: false,
                                       accentColor: .blue, onAdvance: {})
            }
        }
    }

    private final class RecordingTabController: UITabBarController {
        var animationRequests: [Bool] = []
        override func setBottomAccessory(_ bottomAccessory: UITabAccessory?, animated: Bool) {
            animationRequests.append(animated)
            super.setBottomAccessory(bottomAccessory, animated: animated)
        }
    }
}
