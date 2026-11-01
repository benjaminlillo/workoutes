import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class TagTests: XCTestCase {
    private func store() throws -> ModelContainer {
        try ModelContainer(for: Workout.self, WorkoutExercise.self, Tag.self, ExerciseSession.self, ExerciseCompletion.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testSuggestedColorsFollowEveryThemeButMatchingCustomColorsStayFixed() throws {
        let container = try store()
        let context = container.mainContext
        let custom = Tag(name: "Custom", colorHex: TagColorPalette.blue.hex)
        let future = Tag(name: "Future", colorHex: "123456", paletteColorID: "future-color")
        let suggested = TagColorPalette.allCases.map {
            Tag(name: $0.rawValue, colorHex: $0.hex, paletteColorID: $0.rawValue)
        }
        for tag in suggested + [custom, future] { context.insert(tag) }
        for theme in ThemeColor.allCases {
            TagColorSynchronization.apply(theme, to: suggested + [custom, future])
            for (tag, palette) in zip(suggested, TagColorPalette.allCases) {
                XCTAssertEqual(tag.paletteColorID, palette.rawValue)
                XCTAssertEqual(tag.colorHex, palette.hex(for: theme))
            }
            XCTAssertEqual(custom.colorHex, "5B92E5")
            XCTAssertNil(custom.paletteColorID)
            XCTAssertEqual(future.colorHex, "123456")
        }
        try context.save()
        let reopened = try ModelContext(container).fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(reopened.first { $0.name == "blue" }?.paletteColorID, "blue")
        let customChoice = TagColorSelection.custom(TagColorPalette.blue.hex)
        XCTAssertNil(customChoice.paletteID)
        XCTAssertEqual(customChoice.hex(for: .midnightGold), "5B92E5")
    }

    func testBackupAndHistoricalSnapshotsKeepColorIdentityAndLegacyColors() throws {
        let source = try store()
        let palette = Tag(name: "Palette", colorHex: "50B3B1", iconName: "chest", paletteColorID: "teal")
        let custom = Tag(name: "Custom", colorHex: "50B3B1")
        let item = WorkoutExercise(title: "Press", subtitle: "", details: "", numberOfSets: 3, reps: 8,
                                   increaseLoadNextTime: false, weight: 20)
        item.tags = [palette, custom]
        source.mainContext.insert(item)
        let snapshot = ExerciseCompletionSnapshot(exercise: item)
        source.mainContext.insert(ExerciseCompletion(id: "color-snapshot", completedAt: .now, exercise: item, snapshot: snapshot))
        try source.mainContext.save()
        let target = try store()
        try DataBackup.importData(DataBackup.export(from: source.mainContext, includeHistory: true), into: target.mainContext)
        let tags = try target.mainContext.fetch(FetchDescriptor<Tag>())
        TagColorSynchronization.apply(.cherryIce, to: tags)
        XCTAssertEqual(tags.first { $0.name == "Palette" }?.colorHex, "5FBFBA")
        XCTAssertEqual(tags.first { $0.name == "Palette" }?.paletteColorID, "teal")
        XCTAssertEqual(tags.first { $0.name == "Custom" }?.colorHex, "50B3B1")
        XCTAssertNil(tags.first { $0.name == "Custom" }?.paletteColorID)
        let saved = try XCTUnwrap(target.mainContext.fetch(FetchDescriptor<ExerciseCompletion>()).first?.snapshot)
        XCTAssertEqual(saved.tags.first { $0.name == "Palette" }?.resolvedColorHex(for: .cherryIce), "5FBFBA")
        XCTAssertEqual(saved.tags.first { $0.name == "Custom" }?.resolvedColorHex(for: .cherryIce), "50B3B1")
    }

    func testChangingThemeUpdatesExistingTagConsumersThroughTheRootView() async throws {
        let store = try store()
        let suggested = Tag(name: "Suggested", colorHex: "5B92E5", paletteColorID: "blue")
        let custom = Tag(name: "Legacy", colorHex: "5B92E5")
        let item = WorkoutExercise(title: "Press", subtitle: "", details: "", numberOfSets: 3, reps: 8,
                                   increaseLoadNextTime: false, weight: 20)
        item.tags = [suggested, custom]
        store.mainContext.insert(item)
        let record = ExerciseCompletion(id: "theme-preview", completedAt: .now, exercise: item)
        store.mainContext.insert(record)
        try store.mainContext.save()
        let suite = "TagThemeTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = ExerciseActivityController(context: store.mainContext, liveActivitiesEnabled: false)
        let window = UIWindow(windowScene: try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene))
        window.rootViewController = UIHostingController(rootView: ContentView().modelContainer(store)
            .environment(controller).environment(ExerciseBackgroundStore()).defaultAppStorage(defaults))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        for theme in ThemeColor.allCases {
            defaults.set(theme.rawValue, forKey: "appAccentColor")
            try await Task.sleep(for: .milliseconds(150))
            XCTAssertEqual(suggested.colorHex, TagColorPalette.blue.hex(for: theme))
            XCTAssertEqual(custom.colorHex, "5B92E5")
            XCTAssertTrue(item.activityContent.tagColors?.contains(TagColorPalette.blue.hex(for: theme)) == true)
            let chart = WeeklyTagDistribution(summary: WeeklySummary(completions: [record], date: .now))
            XCTAssertTrue(chart.entries.contains { $0.colorHex == TagColorPalette.blue.hex(for: theme) })
        }
    }

    func testDeletingTagKeepsExercisesAndOtherTags() throws {
        let container = try ModelContainer(
            for: Workout.self, WorkoutExercise.self, Tag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let removed = Tag(name: "Upper Body", colorHex: "0000FF")
        let retained = Tag(name: "Strength", colorHex: "00FF00")
        let exercise = WorkoutExercise(title: "Bench Press", subtitle: "", details: "",
                                       numberOfSets: 3, reps: 10, increaseLoadNextTime: false, weight: 20)
        context.insert(removed)
        context.insert(retained)
        context.insert(exercise)
        exercise.tags = [removed, retained]
        try context.save()

        context.delete(removed)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutExercise>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 1)
        XCTAssertEqual(exercise.tags.map(\.name), ["Strength"])
    }
}
