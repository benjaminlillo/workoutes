import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class MuscleIconTests: XCTestCase {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testIconAndColorPersistAndRoundTripIncludingUnknownFutureIcons() throws {
        let source = try container()
        let context = source.mainContext
        let originals = [Tag(name: "Chest", colorHex: "326884", iconName: "chest"),
                         Tag(name: "Legs", colorHex: "B15D78", iconName: "lowerBody"),
                         Tag(name: "Strength", colorHex: "8064B5"),
                         Tag(name: "Future", colorHex: "228844", iconName: "future-muscle")]
        for tag in originals { context.insert(tag) }
        try context.save()
        let reloaded = ModelContext(source)
        let saved = try reloaded.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(saved.first { $0.name == "Chest" }?.muscleIcon, .chest)
        XCTAssertEqual(saved.first { $0.name == "Legs" }?.iconName, "lowerBody")
        XCTAssertNil(saved.first { $0.name == "Strength" }?.muscleIcon)
        XCTAssertNil(saved.first { $0.name == "Future" }?.muscleIcon)

        let backup = try DataBackup.export(from: context, includeHistory: true)
        let destination = try container()
        try DataBackup.importData(backup, into: destination.mainContext)
        try DataBackup.importData(backup, into: destination.mainContext)
        let imported = try destination.mainContext.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(imported.count, originals.count)
        for original in originals {
            let tag = try XCTUnwrap(imported.first { $0.stableID == original.stableID })
            XCTAssertEqual(tag.colorHex, original.colorHex)
            XCTAssertEqual(tag.iconName, original.iconName)
        }
    }

    func testOldBackupWithoutIconsStillImportsAndAllowsRemovingAnIcon() throws {
        let store = try container()
        let tag = Tag(name: "Chest", colorHex: "FF0000", iconName: "chest")
        tag.stableID = "tag"
        store.mainContext.insert(tag)
        try store.mainContext.save()
        let backup = Data("""
        {"workouts":[],"exercises":[],"tags":[{"id":"tag","name":"Chest","colorHex":"5599FF"}]}
        """.utf8)
        try DataBackup.importData(backup, into: store.mainContext)
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<Tag>()), 1)
        XCTAssertNil(tag.iconName)
        XCTAssertNil(tag.muscleIcon)
        XCTAssertEqual(tag.colorHex, "5599FF")
    }

    func testAllIconsHaveBothAssetsAndTheirHighlightsFollowTheTagColor() throws {
        for icon in MuscleIcon.allCases {
            XCTAssertNotNil(UIImage(named: icon.baseAsset), icon.rawValue)
            XCTAssertNotNil(UIImage(named: icon.highlightAsset), icon.rawValue)
            func render(_ color: Color) throws -> Data {
                let renderer = ImageRenderer(content: MuscleIconView(icon: icon, color: color)
                    .frame(width: 32, height: 32).background(.white))
                return try XCTUnwrap(renderer.uiImage?.pngData())
            }
            XCTAssertNotEqual(try render(.red), try render(.blue), "The highlight must be visible and tintable: \(icon.rawValue)")
        }
    }

    func testTagChipsAndPickerRenderInLightAndDarkMode() async throws {
        let store = try container()
        let tags = [Tag(name: "Chest", colorHex: "326884", iconName: "chest"),
                    Tag(name: "Shoulders", colorHex: "8064B5", iconName: "shoulders"),
                    Tag(name: "Legs", colorHex: "B15D78", iconName: "lowerBody")]
        for tag in tags { store.mainContext.insert(tag) }
        try store.mainContext.save()
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: VStack(alignment: .leading, spacing: 12) {
                ForEach(tags) { tag in
                    HStack {
                        TagSelectionLabel(tag: tag, isSelected: false)
                        TagSelectionLabel(tag: tag, isSelected: true)
                    }
                }
            }.padding(16).frame(width: 398).background(DefaultScreenBackground()).environment(\.colorScheme, scheme))
            renderer.scale = 3
            let data = try XCTUnwrap(renderer.uiImage?.pngData())
            try data.write(to: URL(fileURLWithPath: "/tmp/workoutes-muscle-tags-\(scheme == .dark ? "dark" : "light").png"))
        }

        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let views: [(String, AnyView)] = [
            ("editor", AnyView(ManageTagSheet(editingTag: tags[0]).modelContainer(store))),
            ("picker", AnyView(NavigationStack { MuscleIconPicker(selection: .constant(.chest), color: Color(hex: tags[0].colorHex)) }))
        ]
        for (name, view) in views {
            window.rootViewController = UIHostingController(rootView: view)
            window.overrideUserInterfaceStyle = .light
            try await Task.sleep(for: .milliseconds(350))
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-muscle-\(name).png"))
        }
    }
}
