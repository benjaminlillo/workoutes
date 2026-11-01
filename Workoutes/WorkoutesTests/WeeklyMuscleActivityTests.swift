import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class WeeklyMuscleActivityTests: XCTestCase {
    private func store() throws -> ModelContainer {
        try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func exercise(tags: [Tag]) -> WorkoutExercise {
        let item = WorkoutExercise(title: "Press", subtitle: "", details: "", numberOfSets: 3,
                                   reps: 10, increaseLoadNextTime: false, weight: 20)
        item.tags = tags
        return item
    }

    func testCountsSelectedWeekAndKeepsOverlappingAndUnmappedTagsSeparate() throws {
        let store = try store()
        let chest = Tag(name: "Pecho", colorHex: "FF8800", iconName: "chest")
        let upper = Tag(name: "Torso", colorHex: "5599FF", iconName: "upperBody")
        let generic = Tag(name: "Fuerza", colorHex: "55BB99")
        let item = exercise(tags: [chest, upper, generic])
        for tag in [chest, upper, generic] { store.mainContext.insert(tag) }
        store.mainContext.insert(item)
        try store.mainContext.save()
        let week = WeeklySummary.interval(containing: .now)
        let records = [
            ExerciseCompletion(id: "1", completedAt: week.start, exercise: item),
            ExerciseCompletion(id: "2", completedAt: week.start.addingTimeInterval(60), exercise: item),
            ExerciseCompletion(id: "3", completedAt: week.start.addingTimeInterval(120), exercise: nil),
            ExerciseCompletion(id: "old", completedAt: week.start.addingTimeInterval(-1), exercise: item)
        ]
        let activity = WeeklyMuscleActivity(summary: WeeklySummary(completions: records, date: .now))
        XCTAssertEqual(activity.entries.count, 4)
        XCTAssertEqual(activity.entries(for: "chest", on: .front).map(\.count), [2, 2])
        XCTAssertEqual(Set(activity.entries(for: "chest", on: .front).compactMap(\.colorHex)), [chest.colorHex, upper.colorHex])
        XCTAssertEqual(activity.entries.first { $0.id == .tag(generic.persistentModelID) }?.count, 2)
        XCTAssertEqual(activity.entries.first { $0.id == .untagged }?.count, 1)
        XCTAssertEqual(activity.callouts(on: .front).count, 2)
        XCTAssertTrue(activity.callouts(on: .back).isEmpty)
        let previous = WeeklyMuscleActivity(summary: WeeklySummary(completions: records, date: week.start.addingTimeInterval(-1)))
        XCTAssertEqual(previous.entries.first?.count, 1)
        let empty = WeeklyMuscleActivity(summary: WeeklySummary(completions: [], date: .now))
        XCTAssertTrue(empty.entries.isEmpty)
        XCTAssertTrue(empty.entries(for: "chest", on: .front).isEmpty)
    }

    func testEveryIconMapsToAlignedBodyAssetsIncludingGeneralIconsAndAbductors() throws {
        for side in MuscleBodySide.allCases {
            for region in ["base"] + side.regions {
                XCTAssertNotNil(UIImage(named: side.asset(region)), side.asset(region))
            }
        }
        for icon in MuscleIcon.allCases {
            let anchor = MuscleBodyAnatomy.anchor(for: icon)
            XCTAssertTrue((0...1).contains(anchor.point.x))
            XCTAssertTrue((0...1).contains(anchor.point.y))
            XCTAssertFalse(MuscleBodyAnatomy.regions(for: icon, on: anchor.side).isEmpty, icon.rawValue)
        }
        XCTAssertEqual(MuscleBodyAnatomy.regions(for: .fullBody, on: .front), MuscleBodySide.front.regions)
        XCTAssertEqual(MuscleBodyAnatomy.regions(for: .abductors, on: .back), ["gluteal-lateral"])
        XCTAssertTrue(MuscleBodyAnatomy.regions(for: .back, on: .front).isEmpty)
    }

    func testCalloutsRemainOrderedSeparatedAndInsideTheChartForCrowdedMuscles() {
        for targets in [[CGFloat](), [5], [120, 120, 120, 121, 122, 126, 130, 250], [250, 250, 250, 250, 250, 250, 250, 250]] {
            let positions = MuscleCalloutLayout.positions(targets: targets, height: 280, spacing: 34)
            XCTAssertEqual(positions.count, targets.count)
            XCTAssertTrue(positions.allSatisfy { $0 >= 17 && $0 <= 263 })
            for (first, second) in zip(positions, positions.dropFirst()) {
                XCTAssertGreaterThanOrEqual(second - first, 34)
            }
        }
    }

    func testCardRendersBothAppearancesEmptyWeeksAndAccessibleCounts() throws {
        let store = try store()
        let tags = [Tag(name: "Pecho", colorHex: "F08B4F", iconName: "chest"),
                    Tag(name: "Hombros", colorHex: "A280D9", iconName: "shoulders"),
                    Tag(name: "Bíceps", colorHex: "E46F94", iconName: "biceps"),
                    Tag(name: "Espalda", colorHex: "55B8AD", iconName: "back"),
                    Tag(name: "Cuádriceps", colorHex: "648DE8", iconName: "quadriceps"),
                    Tag(name: "Glúteos", colorHex: "DCA756", iconName: "glutes"),
                    Tag(name: "Isquios", colorHex: "8DA86B", iconName: "hamstrings")]
        var records: [ExerciseCompletion] = []
        for (index, tag) in tags.enumerated() {
            store.mainContext.insert(tag)
            let item = exercise(tags: [tag])
            store.mainContext.insert(item)
            for count in 0..<(index + 4) {
                records.append(ExerciseCompletion(id: "\(index)-\(count)", completedAt: .now, exercise: item))
            }
        }
        try store.mainContext.save()
        for (name, history, scheme, size) in [
            ("light", records, ColorScheme.light, DynamicTypeSize.large),
            ("dark", records, .dark, .large),
            ("empty", [], .light, .large),
            ("accessible", records, .light, .accessibility3)
        ] {
            let renderer = ImageRenderer(content: WeeklyMuscleActivityCard(summary: WeeklySummary(completions: history, date: .now))
                .padding(16).frame(width: 398).background(DefaultScreenBackground())
                .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertGreaterThan(image.size.height, 350)
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-body-\(name).png"))
        }
    }
}
