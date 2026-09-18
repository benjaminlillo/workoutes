import SwiftData
import XCTest
@testable import Workoutes

@MainActor
final class TagTests: XCTestCase {
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
