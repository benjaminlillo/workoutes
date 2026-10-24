import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class TagWheelTests: XCTestCase {
    func testRotationCrossesTheAtanSeamWithoutJumpingAndSnapsBothWays() {
        var wheel = TagWheelPosition()
        wheel.drag(to: .pi - 0.04, count: 8)
        wheel.drag(to: -.pi + 0.04, count: 8)
        XCTAssertEqual(wheel.position, 0.08 / (.pi / 4), accuracy: 0.0001)
        wheel.snap()
        XCTAssertEqual(wheel.selectedIndex(count: 8), 0)

        // Moving upward on the left rim brings the next tag into the selection point.
        wheel.drag(to: .pi, count: 8)
        wheel.drag(to: -3 * .pi / 4, count: 8)
        wheel.snap()
        XCTAssertEqual(wheel.selectedIndex(count: 8), 1)
        wheel.drag(to: -3 * .pi / 4, count: 8)
        wheel.drag(to: .pi, count: 8)
        wheel.snap()
        XCTAssertEqual(wheel.selectedIndex(count: 8), 0)
    }

    func testLongListsWrapInBothDirectionsAndTapsMatchTheVisibleSector() {
        var wheel = TagWheelPosition()
        for step in 0...42 {
            wheel.drag(to: Double(step) * 2 * .pi / 21, count: 21)
        }
        wheel.snap()
        XCTAssertEqual(wheel.position, 42, accuracy: 0.0001)
        XCTAssertEqual(wheel.selectedIndex(count: 21), 0)
        wheel.select(20, count: 21)
        XCTAssertEqual(wheel.position, 41)
        wheel.select(0, count: 21)
        XCTAssertEqual(wheel.position, 42)

        for count in [1, 2, 3, 5, 8, 21] {
            XCTAssertEqual(TagWheelPosition.angularSpacing(for: count) * Double(count), 2 * .pi, accuracy: 0.0001)
            for index in 0..<count {
                let angle = TagWheelPosition.selectionAngle
                    - (Double(index) - wheel.position) * TagWheelPosition.angularSpacing(for: count)
                XCTAssertEqual(wheel.index(at: atan2(sin(angle), cos(angle)), count: count), index)
            }
        }
    }

    func testSingleTagAndTagRemovalStayWithinAvailableOptions() {
        var wheel = TagWheelPosition()
        wheel.drag(to: 0, count: 1)
        wheel.drag(to: .pi, count: 1)
        wheel.snap()
        XCTAssertEqual(wheel.selectedIndex(count: 1), 0)
        wheel.select(12, count: 15)
        wheel.select(0, count: 3)
        XCTAssertEqual(wheel.selectedIndex(count: 3), 0)
        wheel.selectPosition(17)
        wheel.select(0, count: 1)
        XCTAssertEqual(wheel.position, 0)
        wheel.drag(to: .pi, count: 0)
        wheel.snap()
        XCTAssertEqual(wheel.selectedIndex(count: 0), 0)
    }

    func testRadialDragsAreIgnoredWhileTangentialMotionKeepsRotating() {
        let center = CGPoint(x: 142, y: 142)
        let start = CGPoint(x: 40, y: 40)
        var push = TagWheelDrag()
        push.update(start: start, location: CGPoint(x: 50, y: 50), center: center)
        XCTAssertEqual(push.intent, .radial)
        push.update(start: start, location: CGPoint(x: 75, y: 75), center: center)
        XCTAssertEqual(push.intent, .radial)
        push.update(start: start, location: CGPoint(x: 20, y: 80), center: center)
        XCTAssertEqual(push.intent, .radial, "An ignored radial drag must not activate the filter later in the gesture")

        var outward = TagWheelDrag()
        outward.update(start: start, location: CGPoint(x: 15, y: 15), center: center)
        XCTAssertEqual(outward.intent, .radial)

        var turn = TagWheelDrag()
        turn.update(start: start, location: CGPoint(x: 20, y: 80), center: center)
        XCTAssertEqual(turn.intent, .rotation)
        turn.update(start: start, location: CGPoint(x: 110, y: 110), center: center)
        XCTAssertEqual(turn.intent, .rotation, "A rotation must retain its intent halfway through the gesture")

        var hub = TagWheelDrag()
        hub.update(start: center, location: CGPoint(x: 170, y: 170), center: center)
        XCTAssertEqual(hub.intent, .undecided, "The native center menu must retain its gestures")
    }

    func testWheelOverlayKeepsItsDistanceFromTheScreenBottomWhileTheBarAnimates() async throws {
        let state = BottomBarState()
        let suiteName = "TagWheelTests.Dock.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: BottomBarFixture(state: state).defaultAppStorage(defaults))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(350))
        let fixed = try XCTUnwrap(findHub(in: try XCTUnwrap(window.rootViewController).view))
        let moving = try XCTUnwrap(state.movingView)
        let expanded = fixed.convert(fixed.bounds, to: window)
        let movingExpanded = moving.convert(moving.bounds, to: window)
        XCTAssertEqual(expanded.midY, window.bounds.maxY - TagWheelPicker.bottomInset - TagWheelPicker.diameter / 2, accuracy: 0.5)

        for height: CGFloat in [93, 81, 69, 57, 47] {
            state.bottomHeight = height
            try await Task.sleep(for: .milliseconds(40))
            XCTAssertEqual(fixed.convert(fixed.bounds, to: window).maxY, expanded.maxY, accuracy: 0.5)
        }
        XCTAssertEqual(moving.convert(moving.bounds, to: window).maxY - movingExpanded.maxY, 58, accuracy: 0.5,
                       "The fixture must really change the available content height")

        state.bottomHeight = 105
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertEqual(fixed.convert(fixed.bounds, to: window).maxY, expanded.maxY, accuracy: 0.5)
    }

    func testManagementActionsWaitForMenuDismissalBeforePresentingAnotherInterface() throws {
        let button = TagWheelMenuButton(frame: CGRect(x: 0, y: 0, width: 48, height: 48))
        button.menu = UIMenu(children: [UIAction(title: "Deselect All Tags") { _ in }])
        let interaction = try XCTUnwrap(button.contextMenuInteraction)
        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in button.menu }
        let animator = MenuAnimator()
        var changes = 0

        button.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: nil)
        button.performAfterMenuDismissal { changes += 1 }
        button.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
        XCTAssertEqual(changes, 0, "Selection must wait until the menu's preview has returned")
        animator.complete()
        XCTAssertEqual(changes, 1, "Selection can change once the native preview has finished returning")

        // Closing without choosing anything must leave the wheel unchanged.
        button.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: nil)
        button.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
        animator.complete()
        XCTAssertEqual(changes, 1)

        // UIKit may omit an animator, including when system animations are disabled.
        button.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: nil)
        button.performAfterMenuDismissal { changes += 1 }
        button.contextMenuInteraction(interaction, willEndFor: configuration, animator: nil)
        XCTAssertEqual(changes, 2)

        // Menu action handlers can also arrive after UIKit has started dismissing.
        button.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: nil)
        button.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
        button.performAfterMenuDismissal { changes += 1 }
        XCTAssertEqual(changes, 2)
        animator.complete()
        XCTAssertEqual(changes, 3)
    }

    func testWheelInExerciseScreenWithMuscleIconsAndExternalFilterChanges() async throws {
        let store = try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let definitions: [(String, String, MuscleIcon)] = [
            ("Abdominales", "BB7528", .abdominals), ("Bíceps", "8E56BA", .biceps),
            ("Espalda", "427A9B", .back), ("Piernas", "3C9064", .lowerBody),
            ("Tríceps", "3268E6", .triceps)
        ]
        let tags = definitions.map { Tag(name: $0.0, colorHex: $0.1, iconName: $0.2.rawValue) }
        for tag in tags { store.mainContext.insert(tag) }
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
        navigation.selectedTagIDs = [tags[4].persistentModelID]
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
        // Give this assertion room to inspect multiple real updates in one fade.
        transition.duration = 0.8
        navigation.selectedTagIDs = [tags[0].persistentModelID]
        try await waitFor { transition.outgoing?.alpha == 0 }
        let outgoing = try XCTUnwrap(transition.outgoing, "Outgoing cards must stay visible while the new filter enters")
        XCTAssertFalse(outgoing.subviews.isEmpty)
        XCTAssertEqual(outgoing.transform, .identity, "Crossfades must not slide the cards")
        XCTAssertEqual(list.transform, .identity)
        XCTAssertEqual(outgoing.alpha, 0)
        XCTAssertTrue(outgoing.superview?.accessibilityElementsHidden == true,
                      "Snapshots must not duplicate interactive or accessible cards")
        navigation.selectedTagIDs = [tags[4].persistentModelID]
        try await waitFor { rowCount(in: list) == titles.count }
        XCTAssertTrue(transition.outgoing === outgoing, "Fast changes must reuse the original exit instead of recapturing ghosts")
        XCTAssertTrue(transition.isActive)
        navigation.selectedTagIDs = [tags[0].persistentModelID]
        try await waitFor { rowCount(in: list) == 0 }
        XCTAssertTrue(transition.outgoing === outgoing, "Incoming content changes immediately without restarting its animation")
        try await waitFor { transition.outgoing == nil }
        transition.duration = ExerciseFilterTransition.duration
        XCTAssertNil(transition.outgoing, "Only one temporary outgoing layer may exist, and it must be removed")
        XCTAssertEqual(rowCount(in: list), 0)
        XCTAssertEqual(list.alpha, 1)
        XCTAssertEqual(list.transform, .identity)
        try snapshot(window, name: "no-matches")

        // A fast spin must apply each filter immediately and finish on the newest selection.
        navigation.selectedTagIDs = [tags[4].persistentModelID]
        try await Task.sleep(for: .milliseconds(30))
        navigation.selectedTagIDs = [tags[0].persistentModelID]
        try await Task.sleep(for: .milliseconds(30))
        navigation.selectedTagIDs = []
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertTrue(navigation.selectedTagIDs.isEmpty, "An external reset must not be overwritten by the wheel")
        XCTAssertEqual(rowCount(in: list), titles.count, "A cancelled transition must not restore stale rows")
        XCTAssertEqual(list.alpha, 1)
        XCTAssertEqual(list.transform, .identity)
        XCTAssertNil(transition.outgoing)
        try snapshot(window, name: "all")

        for tag in tags { store.mainContext.delete(tag) }
        try store.mainContext.save()
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertTrue(navigation.selectedTagIDs.isEmpty)
        try snapshot(window, name: "empty")
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

    private func findHub(in view: UIView) -> TagWheelGripView? {
        if let hub = view as? TagWheelGripView { return hub }
        return view.subviews.compactMap { findHub(in: $0) }.first
    }

    private func rowCount(in list: UICollectionView) -> Int {
        (0..<list.numberOfSections).reduce(0) { $0 + list.numberOfItems(inSection: $1) }
    }

    private func snapshot(_ window: UIWindow, name: String) throws {
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-tag-wheel-\(name).png"))
    }

    private final class BottomBarState: ObservableObject {
        @Published var bottomHeight: CGFloat = 105
        var movingView: UIView?
    }

    private final class MenuAnimator: NSObject, UIContextMenuInteractionAnimating {
        var previewViewController: UIViewController? { nil }
        private var completions: [() -> Void] = []

        func addAnimations(_ animations: @escaping () -> Void) { animations() }
        func addCompletion(_ completion: @escaping () -> Void) { completions.append(completion) }

        func complete() {
            let pending = completions
            completions.removeAll()
            pending.forEach { $0() }
        }
    }

    private struct BottomBarFixture: View {
        @ObservedObject var state: BottomBarState

        var body: some View {
            ScrollView { Color.clear.frame(height: 2_000) }
                .overlay(alignment: .bottomLeading) {
                    FrameProbe { state.movingView = $0 }.frame(width: 80, height: 80)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: state.bottomHeight)
                }
                .overlay {
                    DockableTagWheel(tags: [], selection: .constant(nil), onAdd: {}, onEdit: { _ in }, onDelete: { _ in })
                }
        }
    }

    private struct FrameProbe: UIViewRepresentable {
        let onCreate: (UIView) -> Void

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            onCreate(view)
            return view
        }

        func updateUIView(_ view: UIView, context: Context) {}
    }
}
