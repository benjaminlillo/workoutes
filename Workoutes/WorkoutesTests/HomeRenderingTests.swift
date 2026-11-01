import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class HomeRenderingTests: XCTestCase {
    func testSkeletonWindowIsBoundedAndNeverIncludesFutureWeeks() throws {
        let calendar = Calendar.current
        let current = WeeklySummary.interval(containing: .now).start
        func week(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset * 7, to: current)! }
        XCTAssertEqual(SummaryWeekLoadingState.skeletonWeeks(around: current, through: current),
                       Set([week(-2), week(-1), current]))
        XCTAssertEqual(SummaryWeekLoadingState.skeletonWeeks(around: week(-5), through: current),
                       Set((-7 ... -3).map(week)))
        XCTAssertEqual(SummaryWeekLoadingState.skeletonWeeks(around: week(-1), through: current),
                       Set((-3...0).map(week)))
    }

    func testWeekLoadingWaitsForSettlingAndCancelsSupersededRequests() async throws {
        let loader = SummaryWeekLoadingState()
        let first = WeeklySummary.interval(containing: .now).start
        let second = Calendar.current.date(byAdding: .day, value: -7, to: first)!
        let third = Calendar.current.date(byAdding: .day, value: -14, to: first)!
        await loader.load(SummaryWeekLoadRequest(week: first, isScrolling: true))
        XCTAssertNil(loader.loadedWeek)
        let canceled = Task { await loader.load(SummaryWeekLoadRequest(week: first, isScrolling: false)) }
        try await Task.sleep(for: .milliseconds(20))
        canceled.cancel()
        await canceled.value
        XCTAssertNil(loader.loadedWeek)
        await loader.load(SummaryWeekLoadRequest(week: first, isScrolling: false))
        XCTAssertEqual(loader.loadedWeek, first)
        let superseded = Task { await loader.load(SummaryWeekLoadRequest(week: second, isScrolling: false)) }
        try await Task.sleep(for: .milliseconds(20))
        superseded.cancel()
        await loader.load(SummaryWeekLoadRequest(week: third, isScrolling: false))
        await superseded.value
        XCTAssertEqual(loader.loadedWeek, third)
        await loader.load(SummaryWeekLoadRequest(week: second, isScrolling: true))
        XCTAssertEqual(loader.loadedWeek, third, "Dragging alone must not create another statistics page")
    }

    func testBodyTextureIsReusedButUpdatesForPaletteAnatomySizeScaleAndAppearance() throws {
        let store = try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let tag = Tag(name: "Pecho", colorHex: "FF0000", iconName: "chest")
        let item = WorkoutExercise(title: "Press", subtitle: "", details: "", numberOfSets: 3,
                                   reps: 10, increaseLoadNextTime: false, weight: 20)
        item.tags = [tag]
        store.mainContext.insert(tag); store.mainContext.insert(item)
        try store.mainContext.save()
        let record = ExerciseCompletion(id: "one", completedAt: .now, exercise: item)
        let cache = MuscleBodyImageCache()
        func image(_ history: [ExerciseCompletion] = [record], side: MuscleBodySide = .front,
                   size: CGSize = CGSize(width: 140, height: 280), scale: CGFloat = 2, dark: Bool = false) -> UIImage {
            cache.image(side: side, activity: WeeklyMuscleActivity(summary: WeeklySummary(completions: history, date: .now)),
                        size: size, scale: scale, isDark: dark)
        }
        let first = image()
        XCTAssertTrue(first === image())
        XCTAssertEqual(first.cgImage?.width, 280)
        XCTAssertEqual(first.cgImage?.height, 560)
        tag.name = "Renombrado"
        XCTAssertTrue(first === image([record, ExerciseCompletion(id: "two", completedAt: .now, exercise: item)]))
        XCTAssertFalse(first === image(dark: true))
        XCTAssertFalse(first === image(scale: 3))
        XCTAssertFalse(first === image(size: CGSize(width: 160, height: 320)))
        XCTAssertFalse(first === image(side: .back))
        tag.colorHex = "0000FF"
        let blue = image()
        XCTAssertFalse(first === blue)
        XCTAssertNotEqual(first.pngData(), blue.pngData())
        tag.iconName = "quadriceps"
        XCTAssertNotEqual(blue.pngData(), image().pngData())
    }

    func testDiagramSnapshotUpdatesNumbersAndAppearanceWithoutRepaintingOnReentry() throws {
        let store = try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let tag = Tag(name: "Pecho", colorHex: "FF0000", iconName: "chest")
        let item = WorkoutExercise(title: "Press", subtitle: "", details: "", numberOfSets: 3,
                                   reps: 10, increaseLoadNextTime: false, weight: 20)
        item.tags = [tag]
        store.mainContext.insert(tag); store.mainContext.insert(item)
        try store.mainContext.save()
        let one = ExerciseCompletion(id: "1", completedAt: .now, exercise: item)
        let two = ExerciseCompletion(id: "2", completedAt: .now, exercise: item)
        let cache = MuscleDiagramImageCache()
        func image(_ history: [ExerciseCompletion], scheme: ColorScheme = .light,
                   type: DynamicTypeSize = .large, locale: Locale = Locale(identifier: "en")) throws -> UIImage {
            let activity = WeeklyMuscleActivity(summary: WeeklySummary(completions: history, date: .now))
            let style = MuscleDiagramStyle(colorScheme: scheme, contrast: .standard,
                dynamicTypeSize: type, locale: locale, scale: 2)
            return try XCTUnwrap(cache.image(activity: activity, size: CGSize(width: 350, height: 280), badgeHeight: 26, style: style) {
                MuscleDiagramDrawing(activity: activity, badgeHeight: 26, background: style.background)
            })
        }
        let first = try image([one])
        XCTAssertTrue(first === (try image([one])))
        XCTAssertEqual(first.cgImage?.width, 700)
        XCTAssertEqual(first.cgImage?.height, 560)
        tag.name = "Renombrado"
        XCTAssertTrue(first === (try image([one])))
        let second = try image([one, two])
        XCTAssertFalse(first === second)
        XCTAssertNotEqual(first.pngData(), second.pngData(), "The cached labels must show the new count")
        XCTAssertNotEqual(first.pngData(), try image([one], scheme: .dark).pngData())
        XCTAssertFalse(first === (try image([one], type: .xxxLarge)))
        XCTAssertFalse(first === (try image([one], locale: Locale(identifier: "ar"))))
        tag.colorHex = "0000FF"
        XCTAssertNotEqual(first.pngData(), try image([one]).pngData())
    }

    func testComposedBodyPreservesBothColorsForOverlappingTags() throws {
        let store = try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let red = Tag(name: "A", colorHex: "FF0000", iconName: "chest")
        let blue = Tag(name: "B", colorHex: "0000FF", iconName: "chest")
        let item = WorkoutExercise(title: "Press", subtitle: "", details: "", numberOfSets: 3,
                                   reps: 10, increaseLoadNextTime: false, weight: 20)
        item.tags = [red, blue]
        store.mainContext.insert(red); store.mainContext.insert(blue); store.mainContext.insert(item)
        try store.mainContext.save()
        let summary = WeeklySummary(completions: [ExerciseCompletion(id: "one", completedAt: .now, exercise: item)], date: .now)
        let image = MuscleBodyImageCache().image(side: .front, activity: WeeklyMuscleActivity(summary: summary),
                                                size: CGSize(width: 140, height: 280), scale: 2, isDark: false)
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var redPixels = 0, bluePixels = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            if pixels[index] > 180 && pixels[index + 2] < 70 { redPixels += 1 }
            if pixels[index + 2] > 180 && pixels[index] < 70 { bluePixels += 1 }
        }
        XCTAssertGreaterThan(redPixels, 100)
        XCTAssertGreaterThan(bluePixels, 100)
    }
}
