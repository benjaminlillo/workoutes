import UIKit
import XCTest
@testable import Workoutes

@MainActor
final class ExerciseBackgroundTests: XCTestCase {
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
