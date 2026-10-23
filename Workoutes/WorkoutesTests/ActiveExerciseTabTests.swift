import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class ActiveExerciseTabTests: XCTestCase {
    func testNativeShortcutKeepsItsPlaceAndOnlyEnablesDuringAnExercise() async throws {
        let fixture = try await host()
        defer { fixture.window.isHidden = true }
        let tabs = fixture.tabs
        XCTAssertEqual(tabs.tabBar.items?.count, 5)
        let shortcut = try XCTUnwrap(tabs.tabs.last)
        XCTAssertFalse(shortcut.isEnabled)
        XCTAssertTrue(tabs.tabBar.items?.prefix(4).allSatisfy { $0.title?.isEmpty ?? true } ?? false)
        XCTAssertNil(tabs.bottomAccessory)
        snapshot(fixture.window, name: "idle")

        fixture.controller.toggle(fixture.exercise, context: fixture.store.mainContext)
        await fixture.controller.waitForPendingUpdates()
        XCTAssertTrue(fixture.controller.isActive(fixture.exercise), fixture.controller.errorMessage ?? "")
        try await waitUntil { shortcut.isEnabled }
        XCTAssertEqual(tabs.tabBar.items?.count, 5)
        XCTAssertEqual(fixture.navigation.selectedTab, .settings)
        XCTAssertEqual(tabs.selectedIndex, 3)
        XCTAssertNil(tabs.bottomAccessory)
        if #available(iOS 27.0, *) { XCTAssertNotNil(tabs.prominentTabIdentifier) }
        try await Task.sleep(for: .milliseconds(600))
        snapshot(fixture.window, name: "active")
        fixture.window.overrideUserInterfaceStyle = .dark
        try await Task.sleep(for: .milliseconds(400))
        snapshot(fixture.window, name: "active-dark")

        fixture.controller.toggle(fixture.exercise, context: fixture.store.mainContext)
        await fixture.controller.waitForPendingUpdates()
        XCTAssertFalse(fixture.controller.isActive(fixture.exercise), fixture.controller.errorMessage ?? "")
        try await waitUntil { !shortcut.isEnabled }
        XCTAssertEqual(tabs.tabBar.items?.count, 5)
        XCTAssertEqual(fixture.navigation.selectedTab, .settings)
        XCTAssertNil(tabs.bottomAccessory)
    }

    func testNativeShortcutRevealsExerciseAndCanBeTappedAgain() async throws {
        let fixture = try await host()
        defer { fixture.window.isHidden = true }
        fixture.controller.toggle(fixture.exercise, context: fixture.store.mainContext)
        await fixture.controller.waitForPendingUpdates()
        XCTAssertTrue(fixture.controller.isActive(fixture.exercise), fixture.controller.errorMessage ?? "")
        try await waitUntil { fixture.tabs.tabs.last?.isEnabled == true }
        let tabs = fixture.tabs
        for _ in 0..<2 {
            // A native tap writes the shortcut's selection before routing to Exercises.
            fixture.navigation.selectedTab = .activeExercise
            try await waitUntil {
                fixture.navigation.selectedTab == .exercises && tabs.selectedIndex == 2
                    && fixture.navigation.revealRequest == nil
            }
            XCTAssertTrue(fixture.controller.isActive(fixture.exercise))
            XCTAssertNil(tabs.bottomAccessory)
        }
    }

    func testStaleShortcutWithNoActiveExerciseKeepsCurrentTab() {
        let navigation = ExerciseNavigation()
        navigation.selectedTab = .activeExercise
        navigation.resolveActiveExerciseShortcut(nil, previousTab: .settings)
        XCTAssertEqual(navigation.selectedTab, .settings)
        XCTAssertNil(navigation.revealRequest)
    }

    private struct Fixture {
        let store: ModelContainer
        let exercise: WorkoutExercise
        let controller: ExerciseActivityController
        let navigation: ExerciseNavigation
        let window: UIWindow
        let tabs: UITabBarController
    }

    private func host() async throws -> Fixture {
        let store = try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self,
                                       ExerciseSession.self, ExerciseCompletion.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let exercise = WorkoutExercise(title: "Press de banca", subtitle: "Pecho", details: "",
                                       numberOfSets: 3, reps: 10, increaseLoadNextTime: false, weight: 30)
        store.mainContext.insert(exercise)
        try store.mainContext.save()
        let controller = ExerciseActivityController(context: store.mainContext, liveActivitiesEnabled: false)
        let navigation = ExerciseNavigation()
        navigation.selectedTab = .settings
        let root = UIHostingController(rootView: ContentView(navigation: navigation)
            .environment(controller).environment(ExerciseBackgroundStore()).modelContainer(store))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.overrideUserInterfaceStyle = .light
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        try await waitUntil { self.findTabs(root)?.tabBar.items?.count == 5 }
        await controller.waitForPendingUpdates()
        try await Task.sleep(for: .milliseconds(400))
        let tabs = try XCTUnwrap(findTabs(root))
        return Fixture(store: store, exercise: exercise, controller: controller,
                       navigation: navigation, window: window, tabs: tabs)
    }

    private func findTabs(_ root: UIViewController) -> UITabBarController? {
        if let tabs = root as? UITabBarController { return tabs }
        return root.children.compactMap { findTabs($0) }.first
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(30))
        }
        XCTFail("The native tab bar did not reach the expected state", file: file, line: line)
    }

    private func snapshot(_ window: UIWindow, name: String) {
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try? image.pngData()?.write(to: URL(fileURLWithPath: "/tmp/workoutes-navbar-\(name).png"))
    }
}
