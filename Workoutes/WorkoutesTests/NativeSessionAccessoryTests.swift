import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class NativeSessionAccessoryTests: XCTestCase {
    func testAccessoryRemainsAttachedAcrossSessionStates() async throws {
        let state = TestState()
        let (window, tabs) = try await host(state)
        defer { window.isHidden = true }
        let accessory = try XCTUnwrap(tabs.bottomAccessory)

        state.content = content("Exercise")
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(tabs.bottomAccessory === accessory)

        state.content = nil
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(tabs.bottomAccessory === accessory)
    }

    func testAccessoryRemainsAttachedWhenChangingTabs() async throws {
        let state = TestState()
        let (window, tabs) = try await host(state)
        defer { window.isHidden = true }
        let accessory = try XCTUnwrap(tabs.bottomAccessory)

        state.selection = 1
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(tabs.selectedIndex, 1)
        XCTAssertTrue(tabs.bottomAccessory === accessory)

        state.selection = 0
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(tabs.selectedIndex, 0)
        XCTAssertTrue(tabs.bottomAccessory === accessory)
    }

    private func host(_ state: TestState) async throws -> (UIWindow, UITabBarController) {
        let root = UIHostingController(rootView: TestTabs(state: state))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.makeKeyAndVisible()
        window.layoutIfNeeded()

        for _ in 0..<100 {
            if let tabs = findTabs(in: root), tabs.bottomAccessory != nil {
                return (window, tabs)
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("The native tab accessory was not attached")
        throw TestError.accessoryMissing
    }

    private func content(_ name: String) -> SessionActivityAttributes.ContentState {
        .init(sessionID: "session", blockID: name, blockName: name, blockKind: .exercise,
              blockStartedAt: .now, sessionStartedAt: .now, restEndsAt: nil,
              currentIndex: 0, totalBlocks: 3, isLastBlock: false, accentColorHex: "007AFF")
    }

    private func findTabs(in controller: UIViewController) -> UITabBarController? {
        if let tabs = controller as? UITabBarController { return tabs }
        return controller.children.compactMap { findTabs(in: $0) }.first
    }

    private final class TestState: ObservableObject {
        @Published var selection = 0
        @Published var content: SessionActivityAttributes.ContentState?
    }

    private struct TestTabs: View {
        @ObservedObject var state: TestState

        var body: some View {
            TabView(selection: $state.selection) {
                Tab("First", systemImage: "1.circle", value: 0) { Text("First") }
                Tab("Second", systemImage: "2.circle", value: 1) { Text("Second") }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewBottomAccessory {
                NativeSessionAccessory(
                    content: state.content,
                    isUpdating: false,
                    onStart: {},
                    onAdvance: {}
                )
            }
        }
    }

    private enum TestError: Error { case accessoryMissing }
}
