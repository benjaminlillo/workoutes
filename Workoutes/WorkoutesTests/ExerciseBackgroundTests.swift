import UIKit
import XCTest
@testable import Workoutes

@MainActor
final class ExerciseBackgroundTests: XCTestCase {
    func testGradientsPersistAndRemainIsolatedPerScreen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let exercises = ExerciseBackgroundStore(directory: directory)
        let firstWorkout = ExerciseBackgroundStore(directory: directory, identifier: "workout-first")
        let secondWorkout = ExerciseBackgroundStore(directory: directory, identifier: "workout-second")
        try exercises.saveGradient(colors: ["AABBCC"])
        try firstWorkout.saveGradient(colors: ["112233", "445566", "778899"])
        XCTAssertEqual(ExerciseBackgroundStore(directory: directory).gradientColors, ["AABBCC"])
        XCTAssertEqual(ExerciseBackgroundStore(directory: directory, identifier: "workout-first").gradientColors,
                       ["112233", "445566", "778899"])
        XCTAssertTrue(secondWorkout.gradientColors.isEmpty)
        XCTAssertThrowsError(try firstWorkout.saveGradient(colors: []))
        XCTAssertThrowsError(try firstWorkout.saveGradient(colors: ["1", "2", "3", "4"]))
        try firstWorkout.remove()
        XCTAssertTrue(ExerciseBackgroundStore(directory: directory, identifier: "workout-first").gradientColors.isEmpty)
        XCTAssertEqual(exercises.gradientColors, ["AABBCC"])
    }

    func testPhotoReplacesGradientAfterReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ExerciseBackgroundStore(directory: directory)
        try store.saveGradient(colors: ["112233"])
        let image = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 60)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 30, height: 60))
        }
        try store.save(data: XCTUnwrap(image.pngData()))
        let reopened = ExerciseBackgroundStore(directory: directory)
        XCTAssertNotNil(reopened.image)
        XCTAssertTrue(reopened.gradientColors.isEmpty)
        try reopened.saveGradient(colors: ["ABCDEF"])
        XCTAssertEqual(ExerciseBackgroundStore(directory: directory).gradientColors, ["ABCDEF"])
        try reopened.remove()
        let cleared = ExerciseBackgroundStore(directory: directory)
        XCTAssertNil(cleared.image)
        XCTAssertTrue(cleared.gradientColors.isEmpty)
    }

    func testBackgroundSurvivesReloadAndCanBeRemoved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ExerciseBackgroundStore(directory: directory)
        XCTAssertNil(store.image)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1500), format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 1500))
        }
        try store.save(data: XCTUnwrap(image.pngData()))
        let saved = try XCTUnwrap(store.image)
        XCTAssertEqual(saved.size.width, 2048)
        XCTAssertEqual(saved.size.height, 1024)
        let reopened = ExerciseBackgroundStore(directory: directory)
        XCTAssertEqual(reopened.image?.size, saved.size)
        try reopened.remove()
        XCTAssertNil(reopened.image)
        XCTAssertNil(ExerciseBackgroundStore(directory: directory).image)
        XCTAssertNoThrow(try reopened.remove())
    }

    func testInvalidReplacementPreservesExistingBackground() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ExerciseBackgroundStore(directory: directory)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 60)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 30, height: 60))
        }
        try store.save(data: XCTUnwrap(image.pngData()))
        let previousData = try XCTUnwrap(store.image?.pngData())
        XCTAssertThrowsError(try store.save(data: Data("invalid image".utf8)))
        XCTAssertEqual(store.image?.pngData(), previousData)
        XCTAssertEqual(ExerciseBackgroundStore(directory: directory).image?.pngData(), previousData)
    }
}
