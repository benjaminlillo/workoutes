import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class TagWheelMenuTests: XCTestCase {
    func testUnchangedUpdatesReuseTheMenuAndSelectionReusesItsImages() throws {
        let fixture = try fixture()
        let view = menu(tags: fixture.tags)
        let coordinator = view.makeCoordinator()
        let button = TagWheelMenuButton(frame: .zero)
        view.updateMenu(button, coordinator: coordinator, theme: .primary, scheme: .light, scale: 3)
        let initial = try XCTUnwrap(button.menu)
        let images = try options(button).map { try XCTUnwrap($0.image) }

        // Safe-area and animation updates must not recreate the closed menu.
        for _ in 0..<120 {
            view.updateMenu(button, coordinator: coordinator, theme: .primary, scheme: .light, scale: 3)
        }
        XCTAssertTrue(button.menu === initial)

        menu(tags: fixture.tags, selection: fixture.tags[0].persistentModelID)
            .updateMenu(button, coordinator: coordinator, theme: .primary, scheme: .light, scale: 3)
        let selected = try options(button)
        XCTAssertFalse(button.menu === initial)
        XCTAssertEqual(selected[0].state, .on)
        XCTAssertEqual(selected[1].state, .off)
        XCTAssertTrue(selected[0].image === images[0])
        XCTAssertTrue(selected[1].image === images[1])
        XCTAssertEqual(try deselect(button).attributes.contains(.disabled), false)

        view.updateMenu(button, coordinator: coordinator, theme: .primary, scheme: .light, scale: 3)
        XCTAssertTrue(try deselect(button).attributes.contains(.disabled))
        XCTAssertTrue(try options(button)[0].image === images[0])
    }

    func testTagEditsAppearanceAndAvailableOptionsInvalidateOnlyTheAffectedImages() throws {
        let fixture = try fixture()
        let coordinator = TagWheelMenu.Coordinator()
        let button = TagWheelMenuButton(frame: .zero)
        func update(theme: ThemeColor = .primary, scheme: ColorScheme = .light, scale: CGFloat = 3) {
            menu(tags: fixture.tags).updateMenu(button, coordinator: coordinator, theme: theme, scheme: scheme, scale: scale)
        }
        update()
        let first = try XCTUnwrap(options(button)[0].image)
        let second = try XCTUnwrap(options(button)[1].image)

        fixture.tags[0].name = "Pectorales"
        update()
        XCTAssertEqual(try options(button)[0].title, "Pectorales")
        XCTAssertTrue(try options(button)[0].image === first)

        fixture.tags[0].colorHex = "FF8000"
        update()
        let recolored = try XCTUnwrap(options(button)[0].image)
        XCTAssertFalse(recolored === first)
        XCTAssertTrue(try options(button)[1].image === second)

        fixture.tags[0].iconName = MuscleIcon.upperBody.rawValue
        update()
        let newIcon = try XCTUnwrap(options(button)[0].image)
        XCTAssertFalse(newIcon === recolored)
        let addImage = try XCTUnwrap(management(button)[0].image)
        update(theme: .sunsetPop)
        XCTAssertTrue(try options(button)[0].image === newIcon)
        XCTAssertFalse(try management(button)[0].image === addImage)

        update(theme: .sunsetPop, scheme: .dark)
        let dark = try XCTUnwrap(options(button)[0].image)
        XCTAssertFalse(dark === newIcon)
        XCTAssertEqual(dark.scale, 3)
        update(theme: .sunsetPop, scheme: .dark, scale: 2)
        XCTAssertFalse(try options(button)[0].image === dark)
        XCTAssertEqual(try XCTUnwrap(options(button)[0].image).scale, 2)

        menu(tags: [fixture.tags[1]]).updateMenu(button, coordinator: coordinator, theme: .primary, scheme: .light, scale: 3)
        XCTAssertEqual(try options(button).map(\.title), [fixture.tags[1].name])
        menu(tags: []).updateMenu(button, coordinator: coordinator, theme: .primary, scheme: .light, scale: 3)
        XCTAssertEqual(button.menu?.children.count, 1)
        let remaining = try XCTUnwrap(button.menu?.children.first as? UIMenu)
        XCTAssertEqual(remaining.children.compactMap { ($0 as? UIAction)?.title }, ["Add Tag"])
    }

    func testCachedActionsUseCurrentCallbacksAndCannotSelectRemovedTags() throws {
        let fixture = try fixture()
        let coordinator = TagWheelMenu.Coordinator()
        let button = TagWheelMenuButton(frame: .zero)
        var oldCalls = 0
        var newCalls = 0
        menu(tags: fixture.tags, onChoose: { _ in oldCalls += 1 })
            .updateMenu(button, coordinator: coordinator, theme: .primary, scheme: .light, scale: 3)
        let initial = try XCTUnwrap(button.menu)
        let choose = try options(button)[0]

        menu(tags: fixture.tags, onChoose: { _ in newCalls += 1 })
            .updateMenu(button, coordinator: coordinator, theme: .primary, scheme: .light, scale: 3)
        XCTAssertTrue(button.menu === initial)
        button.sendAction(choose)
        XCTAssertEqual(oldCalls, 0)
        XCTAssertEqual(newCalls, 1)

        menu(tags: [], onChoose: { _ in newCalls += 1 })
            .updateMenu(button, coordinator: coordinator, theme: .primary, scheme: .light, scale: 3)
        button.sendAction(choose)
        XCTAssertEqual(newCalls, 1, "An action retained during menu dismissal must not select a removed tag")
    }

    private func fixture() throws -> (store: ModelContainer, tags: [Tag]) {
        let store = try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let tags = [Tag(name: "Pecho", colorHex: "3268E6", iconName: MuscleIcon.chest.rawValue),
                    Tag(name: "Espalda", colorHex: "3C9064", iconName: MuscleIcon.back.rawValue)]
        for tag in tags { store.mainContext.insert(tag) }
        try store.mainContext.save()
        return (store, tags)
    }

    private func menu(tags: [Tag], selection: PersistentIdentifier? = nil,
                      onChoose: @escaping (Tag) -> Void = { _ in }) -> TagWheelMenu {
        TagWheelMenu(tags: tags, selection: selection, color: .blue, onChoose: onChoose,
                     onDeselect: {}, onAdd: {}, onEdit: { _ in }, onDelete: { _ in })
    }

    private func options(_ button: TagWheelMenuButton) throws -> [UIAction] {
        let section = try XCTUnwrap(button.menu?.children.first as? UIMenu)
        return try XCTUnwrap(section.children as? [UIAction])
    }

    private func deselect(_ button: TagWheelMenuButton) throws -> UIAction {
        let section = try XCTUnwrap(button.menu?.children[1] as? UIMenu)
        return try XCTUnwrap(section.children.first as? UIAction)
    }

    private func management(_ button: TagWheelMenuButton) throws -> [UIAction] {
        let section = try XCTUnwrap(button.menu?.children.last as? UIMenu)
        return section.children.compactMap { $0 as? UIAction }
    }
}
