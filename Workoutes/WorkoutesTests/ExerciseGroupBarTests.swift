import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class ExerciseGroupBarTests: XCTestCase {
    func testScrollableGroupBarAndExternalFilterChanges() async throws {
        let store = try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let definitions: [(String, String, MuscleIcon)] = [
            ("Abdominales", "BB7528", .abdominals), ("Bíceps", "8E56BA", .biceps),
            ("Espalda", "427A9B", .back), ("Piernas", "3C9064", .lowerBody),
            ("Tríceps", "3268E6", .triceps)
        ]
        let tags = definitions.map { Tag(name: $0.0, colorHex: $0.1, iconName: $0.2.rawValue) }
        for tag in tags { store.mainContext.insert(tag) }
        let filterGroups = tags.map { tag in
            TagGroup(name: tag.name, colorHex: tag.colorHex, iconName: tag.iconName, tags: [tag])
        }
        let groups = filterGroups + (1...8).map { TagGroup(name: "Grupo \($0)", colorHex: "A484D1", iconName: "core") }
        for group in groups { store.mainContext.insert(group) }
        let titles = ["Fondos de tríceps", "Tríceps polea alta agarre V o recto", "Tríceps polea alta con cuerda", "Extensión de tríceps"]
        for title in titles {
            let item = WorkoutExercise(title: title, subtitle: "Cabeza larga y media", details: "", numberOfSets: 3,
                                       reps: 10, increaseLoadNextTime: false, weight: 22.5)
            store.mainContext.insert(item)
            item.tags = [tags[4]]
        }
        try store.mainContext.save()
        let navigation = ExerciseNavigation()
        navigation.selectedTab = .exercises
        navigation.selectedGroup = filterGroups[4]
        let activity = ExerciseActivityController(context: store.mainContext, liveActivitiesEnabled: false)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: ContentView(navigation: navigation)
            .environment(activity).environment(ExerciseBackgroundStore()).modelContainer(store).tint(.blue))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        for (name, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            window.overrideUserInterfaceStyle = style
            try await Task.sleep(for: .milliseconds(700))
            try snapshot(window, name: name)
        }

        let transition = try XCTUnwrap(findTransition(in: try XCTUnwrap(window.rootViewController).view))
        let list = try XCTUnwrap(findList(in: try XCTUnwrap(window.rootViewController).view))
        XCTAssertNotNil(findHorizontalScroll(in: window), "Keep scroll content mounted while the glass is compact")
        // Intermediate filter selections must share one bounded exit.
        transition.duration = 0.3
        navigation.selectedGroup = filterGroups[0]
        try await waitFor { transition.outgoing?.alpha == 0 }
        let outgoing = try XCTUnwrap(transition.outgoing, "Outgoing cards must fade before the next entrance")
        XCTAssertFalse(outgoing.subviews.isEmpty)
        XCTAssertEqual(outgoing.transform, .identity, "The fade must not slide the cards")
        XCTAssertEqual(list.transform, .identity)
        XCTAssertEqual(outgoing.alpha, 0)
        XCTAssertTrue(outgoing.superview?.accessibilityElementsHidden == true,
                      "Snapshots must not duplicate interactive or accessible cards")
        navigation.selectedGroup = filterGroups[4]
        try await waitFor { rowCount(in: list) == titles.count }
        XCTAssertTrue(transition.outgoing === outgoing, "Fast changes must reuse the original exit instead of recapturing ghosts")
        XCTAssertTrue(transition.isActive)
        navigation.selectedGroup = filterGroups[0]
        try await waitFor { rowCount(in: list) == 0 }
        XCTAssertTrue(transition.outgoing === outgoing, "Intermediate selections must not restart the exit")
        try await waitFor { transition.outgoing == nil }
        try await waitFor { !transition.isActive }
        transition.duration = ExerciseFilterTransition.duration
        XCTAssertNil(transition.outgoing, "Only one temporary outgoing layer may exist, and it must be removed")
        XCTAssertEqual(rowCount(in: list), 0)
        XCTAssertEqual(list.alpha, 1)
        XCTAssertEqual(list.transform, .identity)
        try snapshot(window, name: "no-matches")

        // Rapid changes can remain blank and must finish on the newest selection.
        navigation.selectedGroup = filterGroups[4]
        try await Task.sleep(for: .milliseconds(30))
        navigation.selectedGroup = filterGroups[0]
        try await Task.sleep(for: .milliseconds(30))
        navigation.selectedGroup = nil
        try await waitFor { !transition.isActive }
        XCTAssertNil(navigation.selectedGroup, "An external reset must not be overwritten by the bar")
        XCTAssertEqual(rowCount(in: list), titles.count, "A cancelled transition must not restore stale rows")
        XCTAssertEqual(list.alpha, 1)
        XCTAssertEqual(list.transform, .identity)
        XCTAssertNil(transition.outgoing)
        XCTAssertTrue(list.visibleCells.allSatisfy { $0.alpha == 1 })
        try snapshot(window, name: "all")

        // Interrupt an actual entrance, including rows still waiting for their stagger.
        navigation.selectedGroup = filterGroups[0]
        try await waitFor { !transition.isActive && rowCount(in: list) == 0 }
        navigation.selectedGroup = filterGroups[4]
        try await waitFor { transition.isEntering }
        try await Task.sleep(for: .milliseconds(100))
        let visibleBounds = list.bounds.inset(by: list.adjustedContentInset)
        let visibleCards = list.visibleCells.filter { $0.frame.intersects(visibleBounds) }
            .sorted { $0.frame.minY < $1.frame.minY }
        XCTAssertGreaterThan(visibleCards.count, 1)
        let top = try XCTUnwrap(visibleCards.first)
        let bottom = try XCTUnwrap(visibleCards.last)
        XCTAssertGreaterThan(top.layer.presentation()?.opacity ?? Float(top.alpha),
                             bottom.layer.presentation()?.opacity ?? Float(bottom.alpha),
                             "Upper cards must appear before lower cards")
        navigation.selectedGroup = filterGroups[0]
        try await waitFor { transition.outgoing != nil }
        XCTAssertFalse(transition.isEntering, "An interrupted entrance must not keep revealing pending cards")
        navigation.selectedGroup = nil
        try await waitFor { !transition.isActive }
        XCTAssertEqual(rowCount(in: list), titles.count)
        XCTAssertTrue(list.visibleCells.allSatisfy { $0.alpha == 1 })
        XCTAssertNil(transition.outgoing)

        // Leaving the screen cancels both scheduled cards and outgoing snapshots.
        navigation.selectedGroup = filterGroups[0]
        try await waitFor { transition.isActive }
        navigation.selectedTab = .settings
        try await waitFor { !transition.isActive }
        XCTAssertNil(transition.outgoing)
        XCTAssertEqual(list.alpha, 1)
        navigation.selectedTab = .exercises
        navigation.selectedGroup = nil
        try await waitFor { rowCount(in: list) == titles.count && !transition.isActive }

        for group in groups { store.mainContext.delete(group) }
        try store.mainContext.save()
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertNil(navigation.selectedGroup)
        try snapshot(window, name: "empty")
    }

    func testExpansionScrollAndCollapsePreserveSelection() async throws {
        let store = try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let groups = (0..<16).map { TagGroup(name: "Group \($0)", colorHex: "3268E6", iconName: "biceps") }
        for group in groups { store.mainContext.insert(group) }
        try store.mainContext.save()
        let state = FilterState()
        state.selection = groups[12].persistentModelID
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView:
            ExerciseGroupBar(groups: groups,
                selection: Binding(get: { state.selection }, set: { state.selection = $0 }),
                isExpanded: Binding(get: { state.expanded }, set: { state.expanded = $0 }))
                .padding(20).frame(maxHeight: .infinity, alignment: .bottom)
                .modelContainer(store))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNotNil(findHorizontalScroll(in: window), "Collapsing must preserve the scroll view for a continuous transition")
        state.expanded = true
        try await Task.sleep(for: .milliseconds(500))
        let horizontal = try XCTUnwrap(findHorizontalScroll(in: window))
        XCTAssertGreaterThan(horizontal.contentOffset.x, 0, "Opening must reveal the selected group")
        horizontal.setContentOffset(.zero, animated: false)
        XCTAssertEqual(state.selection, groups[12].persistentModelID, "Scrolling must not change the filter")
        for (name, style) in [("expanded-light", UIUserInterfaceStyle.light), ("expanded-dark", .dark)] {
            window.overrideUserInterfaceStyle = style
            try await Task.sleep(for: .milliseconds(300))
            try snapshot(window, name: name)
        }
        state.expanded = false
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNotNil(findHorizontalScroll(in: window), "Collapsing must preserve the scroll view for a continuous transition")
        XCTAssertEqual(state.selection, groups[12].persistentModelID)
        state.selection = nil
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(state.expanded, "External filter resets must not expand the control")
    }

    func testAnimatedGlassKeepsItsScrollViewAcrossInterruptions() async throws {
        let store = try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let groups = (0..<12).map { TagGroup(name: "Group \($0)", colorHex: "3268E6", iconName: "biceps") }
        for group in groups { store.mainContext.insert(group) }
        try store.mainContext.save()
        let state = FilterState()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView:
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                ExerciseGroupBar(groups: groups,
                    selection: Binding(get: { state.selection }, set: { state.selection = $0 }),
                    isExpanded: Binding(get: { state.expanded }, set: { state.expanded = $0 }))
                    .padding(20).padding(.bottom, 80)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }.modelContainer(store))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .seconds(1))
        let scroll = try XCTUnwrap(findHorizontalScroll(in: window))
        for style in [UIUserInterfaceStyle.light, .dark] {
            window.overrideUserInterfaceStyle = style
            try await Task.sleep(for: .milliseconds(500))
            state.expanded = true
            try await Task.sleep(for: .milliseconds(800))
            XCTAssertTrue(findHorizontalScroll(in: window) === scroll)
            state.selection = groups[2].persistentModelID
            state.expanded = false
            try await Task.sleep(for: .milliseconds(800))
            state.expanded = true
            try await Task.sleep(for: .milliseconds(120))
            state.expanded = false
            try await Task.sleep(for: .milliseconds(120))
            state.expanded = true
            try await Task.sleep(for: .milliseconds(800))
            XCTAssertTrue(findHorizontalScroll(in: window) === scroll,
                          "Interruptions must animate the existing surface, not replace its contents")
            state.expanded = false
            try await Task.sleep(for: .milliseconds(800))
        }
    }

    @Observable
    final class FilterState {
        var selection: PersistentIdentifier?
        var expanded = false
    }

    private func findHorizontalScroll(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView,
           scroll.contentSize.width > scroll.bounds.width + 44 { return scroll }
        return view.subviews.compactMap { findHorizontalScroll(in: $0) }.first
    }

    private func findList(in view: UIView) -> UICollectionView? {
        if let list = view as? UICollectionView { return list }
        return view.subviews.compactMap { findList(in: $0) }.first
    }

    private func findTransition(in view: UIView) -> ExerciseFilterViewport? {
        if let viewport = view as? ExerciseFilterViewport { return viewport }
        return view.subviews.compactMap { findTransition(in: $0) }.first
    }

    private func waitFor(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(condition(), "The transition must finish within its bounded lifetime")
    }

    private func rowCount(in list: UICollectionView) -> Int {
        (0..<list.numberOfSections).reduce(0) { $0 + list.numberOfItems(inSection: $1) }
    }

    private func snapshot(_ window: UIWindow, name: String) throws {
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-group-bar-\(name).png"))
    }

}
