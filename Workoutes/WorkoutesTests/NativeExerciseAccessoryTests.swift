import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class NativeExerciseAccessoryTests: XCTestCase {
    func testAccessoryAttachesToSwiftUITabViewAndSurvivesTabChanges() async throws {
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
        try await Task.sleep(for: .milliseconds(500))
        state.content = content("Active")
        try await Task.sleep(for: .milliseconds(80))
        let accessory = try XCTUnwrap(actualTabs.bottomAccessory)
        actualTabs.selectedIndex = 1
        state.content = content("Updated")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(actualTabs.bottomAccessory === accessory)

        try await Task.sleep(for: .milliseconds(500))
        state.content = nil
        try await Task.sleep(for: .milliseconds(80))
        for _ in 0..<100 {
            if actualTabs.bottomAccessory == nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNil(actualTabs.bottomAccessory)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(actualTabs.tabBarMinimizeBehavior, .never)
    }

    func testRapidReactivationKeepsAccessoryVisibleAfterDismissal() async throws {
        let state = TestState()
        let root = UIHostingController(rootView: TestTabs(state: state))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(500))
        let tabs = try XCTUnwrap(findTabs(in: root))

        state.content = content("First")
        try await Task.sleep(for: .milliseconds(500))
        for index in 0..<4 {
            state.content = nil
            try await Task.sleep(for: .milliseconds(60))
            state.content = content("Restarted \(index)")
            try await Task.sleep(for: .milliseconds(700))
            XCTAssertNotNil(tabs.bottomAccessory)
            let host = try XCTUnwrap(tabs.children.compactMap { $0 as? NativeExerciseAccessory.AccessoryHost }.first)
            XCTAssertEqual(host.state.content.title, "Restarted \(index)")
            XCTAssertTrue(host.view.window === window, "The active exercise must remain attached after the previous dismissal finishes")
            XCTAssertFalse(host.view.isHidden)
            XCTAssertEqual(host.view.alpha, 1)
            XCTAssertTrue(host.view.isUserInteractionEnabled)
            XCTAssertEqual(tabs.tabBarMinimizeBehavior, .onScrollDown)
        }
    }

    func testInsertionAndRemovalUseOnlyNativeAnimation() async {
        let tabs = RecordingTabController()
        tabs.viewControllers = [UIViewController()]
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        let bridge = NativeExerciseAccessory.Controller()
        tabs.addChild(bridge)
        tabs.view.addSubview(bridge.view)
        bridge.didMove(toParent: tabs)
        defer {
            bridge.tearDown()
            window.isHidden = true
        }

        bridge.configuration = configuration(nil)
        bridge.scheduleUpdate()
        await nextMainQueueTurn()
        XCTAssertNil(tabs.bottomAccessory)

        bridge.configuration = configuration(content("First"))
        bridge.scheduleUpdate()
        await nextMainQueueTurn()
        let accessory = tabs.bottomAccessory
        XCTAssertNotNil(accessory)
        XCTAssertEqual(tabs.animationRequests, [!UIAccessibility.isReduceMotionEnabled])

        // Switching exercises updates the existing surface instead of inserting it again.
        bridge.configuration = configuration(content("Second"))
        bridge.scheduleUpdate()
        await nextMainQueueTurn()
        XCTAssertTrue(tabs.bottomAccessory === accessory)
        XCTAssertEqual(tabs.animationRequests.count, 1)

        bridge.configuration = configuration(nil)
        bridge.scheduleUpdate()
        await nextMainQueueTurn()
        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertNil(tabs.bottomAccessory)
        XCTAssertEqual(tabs.animationRequests, Array(repeating: !UIAccessibility.isReduceMotionEnabled, count: 2))

        bridge.configuration = configuration(content("Third"))
        bridge.scheduleUpdate()
        await nextMainQueueTurn()
        XCTAssertNotNil(tabs.bottomAccessory)
        XCTAssertEqual(tabs.animationRequests.count, 3)
    }

    private func configuration(_ content: ExerciseActivityAttributes.ContentState?) -> NativeExerciseAccessory {
        NativeExerciseAccessory(content: content, isUpdating: false, accentColor: .blue, onStop: {})
    }

    private func content(_ title: String) -> ExerciseActivityAttributes.ContentState {
        .init(exerciseID: title, title: title, subtitle: "", numberOfSets: 3,
              reps: 10, weight: 20, increaseLoadNextTime: false)
    }

    private func nextMainQueueTurn() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    private func findTabs(in controller: UIViewController) -> UITabBarController? {
        if let tabs = controller as? UITabBarController { return tabs }
        return controller.children.compactMap { findTabs(in: $0) }.first
    }

    private final class TestState: ObservableObject {
        @Published var content: ExerciseActivityAttributes.ContentState?
    }

    private struct TestTabs: View {
        @ObservedObject var state: TestState
        var body: some View {
            TabView {
                Tab("First", systemImage: "1.circle") { Text("First") }
                Tab("Second", systemImage: "2.circle") { Text("Second") }
            }
            .background {
                NativeExerciseAccessory(content: state.content, isUpdating: false,
                                        accentColor: .blue, onStop: {})
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
