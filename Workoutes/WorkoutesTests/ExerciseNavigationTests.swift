import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class ExerciseNavigationTests: XCTestCase {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func exercise(_ title: String) -> WorkoutExercise {
        WorkoutExercise(title: title, subtitle: "", details: "", numberOfSets: 3, reps: 10,
                        increaseLoadNextTime: false, weight: 30)
    }

    func testRevealPreservesFiltersWhenAnySelectedTagMatches() throws {
        let store = try container()
        let item = exercise("Bench Press")
        let matching = Tag(name: "Chest", colorHex: "FF8800")
        let other = Tag(name: "Legs", colorHex: "5599FF")
        store.mainContext.insert(item)
        store.mainContext.insert(matching)
        store.mainContext.insert(other)
        item.tags = [matching]
        try store.mainContext.save()
        let navigation = ExerciseNavigation()
        let group = TagGroup(name: "Upper body", colorHex: "FF8800", tags: [matching, other])
        store.mainContext.insert(group)
        navigation.selectedGroup = group

        navigation.reveal(item)

        XCTAssertEqual(navigation.selectedTab, .exercises)
        XCTAssertEqual(navigation.selectedGroup, group)
        XCTAssertEqual(navigation.revealRequest?.exerciseID, item.persistentModelID)
    }

    func testRevealClearsAllExcludingFiltersAndCanRepeatForSameExercise() throws {
        let store = try container()
        let item = exercise("Untagged Exercise")
        let first = Tag(name: "Chest", colorHex: "FF8800")
        let second = Tag(name: "Legs", colorHex: "5599FF")
        store.mainContext.insert(item)
        store.mainContext.insert(first)
        store.mainContext.insert(second)
        try store.mainContext.save()
        let navigation = ExerciseNavigation()
        let group = TagGroup(name: "Strength", colorHex: "FF8800", tags: [first, second])
        store.mainContext.insert(group)
        navigation.selectedGroup = group
        navigation.selectedTab = .settings

        navigation.reveal(item)
        let firstRequest = try XCTUnwrap(navigation.revealRequest)
        XCTAssertNil(navigation.selectedGroup)
        XCTAssertEqual(navigation.selectedTab, .exercises)

        navigation.reveal(item)
        XCTAssertEqual(navigation.revealRequest?.exerciseID, firstRequest.exerciseID)
        XCTAssertNotEqual(navigation.revealRequest?.id, firstRequest.id)
    }

    func testRevealSwitchesTabsUnfiltersAndScrollsToDistantActiveExercise() async throws {
        let store = try container()
        let context = store.mainContext
        let otherTag = Tag(name: "Other exercises", colorHex: "FF8800")
        context.insert(otherTag)
        let group = TagGroup(name: "Other group", colorHex: "FF8800", tags: [otherTag])
        context.insert(group)
        let items = (0..<30).map { exercise(String(format: "Exercise %02d", $0)) }
        for (index, item) in items.enumerated() {
            context.insert(item)
            if index != 18 { item.tags = [otherTag] }
        }
        try context.save()
        let target = items[18]
        let controller = ExerciseActivityController(context: context, liveActivitiesEnabled: false)
        controller.toggle(target, context: context)
        await controller.waitForPendingUpdates()
        let navigation = ExerciseNavigation()
        navigation.selectedTab = .settings
        navigation.selectedGroup = group
        let root = UIHostingController(rootView: ContentView(navigation: navigation)
            .environment(controller).environment(ExerciseBackgroundStore()).modelContainer(store))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.overrideUserInterfaceStyle = .light
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(300))

        navigation.reveal(target)
        try await waitForReveal(navigation)
        try await Task.sleep(for: .milliseconds(500))
        let tabs = try XCTUnwrap(findTabs(root))
        XCTAssertEqual(tabs.selectedIndex, 2)
        XCTAssertNil(navigation.selectedGroup)
        XCTAssertTrue(controller.isActive(target))
        let list = try XCTUnwrap(findList(try XCTUnwrap(tabs.selectedViewController).view))
        XCTAssertGreaterThan(list.contentOffset.y, 1_000)
        try snapshot(window, name: "first")

        // Repeating the action on an already mounted, filtered list must unfilter and scroll again.
        navigation.selectedGroup = group
        try await Task.sleep(for: .milliseconds(150))
        list.setContentOffset(CGPoint(x: 0, y: -list.adjustedContentInset.top), animated: false)
        try await Task.sleep(for: .milliseconds(100))
        navigation.reveal(target)
        try await waitForReveal(navigation)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertGreaterThan(list.contentOffset.y, 1_000)
        XCTAssertTrue(controller.isActive(target))
        try snapshot(window, name: "repeated")
    }

    private func waitForReveal(_ navigation: ExerciseNavigation) async throws {
        for _ in 0..<100 {
            if navigation.revealRequest == nil { return }
            try await Task.sleep(for: .milliseconds(30))
        }
        XCTFail("The exercise reveal request was not handled")
    }

    private func findTabs(_ root: UIViewController) -> UITabBarController? {
        if let tabs = root as? UITabBarController { return tabs }
        return root.children.compactMap { findTabs($0) }.first
    }

    private func findList(_ view: UIView) -> UICollectionView? {
        if let list = view as? UICollectionView { return list }
        return view.subviews.compactMap { findList($0) }.first
    }

    private func snapshot(_ window: UIWindow, name: String) throws {
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-reveal-\(name).png"))
    }
}
