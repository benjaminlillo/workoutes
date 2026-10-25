import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class WeeklyTagDistributionTests: XCTestCase {
    private func store() throws -> ModelContainer {
        try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func exercise(_ name: String, tags: [Tag] = []) -> WorkoutExercise {
        let item = WorkoutExercise(title: name, subtitle: "", details: "", numberOfSets: 3,
                                   reps: 10, increaseLoadNextTime: false, weight: 20)
        item.tags = tags
        return item
    }

    func testCountsEveryCompletionAndEachTagWithUntaggedExercisesInTheSameWeek() throws {
        let store = try store()
        let chest = Tag(name: "Pecho", colorHex: "E66545")
        let arms = Tag(name: "Brazos", colorHex: "8960BC")
        let bench = exercise("Press", tags: [chest, arms])
        let fly = exercise("Aperturas", tags: [chest])
        let untagged = exercise("Libre")
        for tag in [chest, arms] { store.mainContext.insert(tag) }
        for item in [bench, fly, untagged] { store.mainContext.insert(item) }
        try store.mainContext.save()
        let date = Date.now
        let week = WeeklySummary.interval(containing: date)
        let records = [bench, bench, fly, untagged, nil].enumerated().map {
            ExerciseCompletion(id: "\($0.offset)", completedAt: week.start.addingTimeInterval(Double($0.offset)), exercise: $0.element)
        } + [ExerciseCompletion(id: "before", completedAt: week.start.addingTimeInterval(-1), exercise: bench),
             ExerciseCompletion(id: "after", completedAt: week.end, exercise: bench)]
        let summary = WeeklySummary(completions: records, date: date)
        let distribution = WeeklyTagDistribution(summary: summary)
        XCTAssertEqual(summary.total, 5)
        XCTAssertEqual(distribution.total, 7)
        XCTAssertEqual(distribution.entries.map(\.count), [3, 2, 2])
        let chestEntry = try XCTUnwrap(distribution.entries.first { $0.id == .tag(chest.persistentModelID) })
        XCTAssertEqual(chestEntry.count, 3)
        XCTAssertEqual(chestEntry.colorHex, chest.colorHex)
        XCTAssertEqual(distribution.fraction(for: chestEntry), 3.0 / 7, accuracy: 0.0001)
        XCTAssertEqual(distribution.entries.first { $0.id == .untagged }?.count, 2)
        XCTAssertEqual(distribution.entries.reduce(0.0) { $0 + distribution.fraction(for: $1) }, 1, accuracy: 0.0001)
        XCTAssertEqual(WeeklyTagDistribution(summary: WeeklySummary(completions: records, date: week.end)).total, 2)
    }

    func testMatchesTheWeeklyBlocksAfterCurrentTagsAreRenamedRecoloredOrDeleted() throws {
        let store = try store()
        let tag = Tag(name: "Original", colorHex: "FF8800")
        let item = exercise("Press", tags: [tag])
        store.mainContext.insert(tag)
        store.mainContext.insert(item)
        let completion = ExerciseCompletion(id: "saved", completedAt: .now, exercise: item,
                                            snapshot: ExerciseCompletionSnapshot(exercise: item))
        store.mainContext.insert(completion)
        try store.mainContext.save()
        tag.name = "Pectorales"
        tag.colorHex = "5599FF"
        let summary = WeeklySummary(completions: [completion], date: .now)
        let updated = WeeklyTagDistribution(summary: summary)
        XCTAssertEqual(updated.entries.first?.name, "Pectorales")
        XCTAssertEqual(updated.entries.first?.colorHex, completion.tagColors.first)
        XCTAssertEqual(completion.snapshot?.tags.first?.name, "Original")
        store.mainContext.delete(tag)
        try store.mainContext.save()
        XCTAssertEqual(WeeklyTagDistribution(summary: summary).entries.first?.id, .untagged)
        store.mainContext.delete(item)
        try store.mainContext.save()
        XCTAssertEqual(WeeklyTagDistribution(summary: summary).total, 1)
    }

    func testSameNamedTagsKeepSeparateIdentitiesAndEmptyWeeksHaveNoInventedSlice() throws {
        let store = try store()
        let tags = [Tag(name: "Fuerza", colorHex: "E66545"), Tag(name: "Fuerza", colorHex: "5599FF")]
        for tag in tags { store.mainContext.insert(tag) }
        let item = exercise("Press", tags: tags)
        store.mainContext.insert(item)
        try store.mainContext.save()
        let record = ExerciseCompletion(id: "one", completedAt: .now, exercise: item)
        let distribution = WeeklyTagDistribution(summary: WeeklySummary(completions: [record], date: .now))
        XCTAssertEqual(distribution.entries.count, 2)
        XCTAssertEqual(Set(distribution.entries.map(\.id)).count, 2)
        XCTAssertTrue(distribution.entries.allSatisfy { distribution.fraction(for: $0) == 0.5 })
        let empty = WeeklyTagDistribution(summary: WeeklySummary(completions: [], date: .now))
        XCTAssertTrue(empty.entries.isEmpty)
        XCTAssertEqual(empty.total, 0)
    }

    func testPieRendersEmptySingleTagAndAccessibleLegendsInBothAppearances() async throws {
        let store = try store()
        let tags = [Tag(name: "Pecho", colorHex: "E66545"), Tag(name: "Espalda", colorHex: "4C9F9C"),
                    Tag(name: "Piernas", colorHex: "8960BC"), Tag(name: "Entrenamiento de fuerza de cuerpo completo", colorHex: "D3A433")]
        for tag in tags { store.mainContext.insert(tag) }
        let items = tags.map { exercise($0.name, tags: [$0]) }
        for item in items { store.mainContext.insert(item) }
        try store.mainContext.save()
        let today = Date.now
        let records = (0..<10).map { index in
            ExerciseCompletion(id: "render-\(index)", completedAt: today,
                               exercise: index == 9 ? nil : items[index % items.count])
        }
        for (name, history, scheme, size) in [
            ("empty", [ExerciseCompletion](), ColorScheme.light, DynamicTypeSize.large),
            ("single", [records[0]], .light, .large),
            ("populated", records, .light, .large),
            ("dark", records, .dark, .large),
            ("accessible", records, .light, .accessibility3)
        ] {
            let content = WeeklyTagDistributionChart(summary: WeeklySummary(completions: history, date: today))
                .padding(16).frame(width: 398).background(DefaultScreenBackground())
                .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size)
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
            let window = UIWindow(windowScene: scene)
            let bounds = CGRect(x: 0, y: 0, width: 398, height: size.isAccessibilitySize ? 332 : 209)
            window.frame = bounds
            window.rootViewController = UIHostingController(rootView: content.ignoresSafeArea())
            window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
            window.makeKeyAndVisible()
            window.rootViewController?.view.frame = bounds
            window.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
            let image = UIGraphicsImageRenderer(bounds: bounds).image { _ in
                window.drawHierarchy(in: bounds, afterScreenUpdates: true)
            }
            window.isHidden = true
            XCTAssertEqual(image.size.width, 398, accuracy: 0.5)
            XCTAssertEqual(image.size.height, size.isAccessibilitySize ? 332 : 209, accuracy: 0.5)
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-tag-distribution-\(name).png"))
        }
    }
}
