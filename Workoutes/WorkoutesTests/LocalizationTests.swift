import XCTest
@testable import Workoutes

final class LocalizationTests: XCTestCase {
    func testEnglishAndSpanishResourcesAreBundled() throws {
        for (language, exercises, training) in [("en", "Exercises", "Training"), ("es", "Ejercicios", "Entrenamiento")] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            XCTAssertEqual(bundle.localizedString(forKey: "Exercises", value: nil, table: nil), exercises)
            XCTAssertEqual(bundle.localizedString(forKey: "Training", value: nil, table: nil), training)
        }
    }

    func testSpanishDynamicLabels() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "es", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        let spanish = Locale(identifier: "es")
        XCTAssertEqual(String(localized: "Series \(2) of \(3)", bundle: bundle, locale: spanish), "Serie 2 de 3")
        XCTAssertEqual(String(localized: "Couldn't save training: \("ERROR")", bundle: bundle, locale: spanish), "No se pudo guardar el entrenamiento: ERROR")
    }

    func testPluralCountsInBothLanguages() throws {
        for (language, expected) in [("en", ["0 sets", "1 set", "2 sets"]), ("es", ["0 series", "1 serie", "2 series"])] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for count in 0...2 {
                XCTAssertEqual(String(localized: "\(count) sets", bundle: bundle, locale: Locale(identifier: language)), expected[count])
            }
        }
    }

    func testWatchAndLiveActivityContainBothLanguages() throws {
        for relativePath in ["Watch/WorkoutesWatch.app", "PlugIns/WorkoutesLiveActivity.appex"] {
            let url = Bundle.main.bundleURL.appending(path: relativePath)
            let target = try XCTUnwrap(Bundle(url: url))
            for (language, expected) in [("en", "Sets"), ("es", "Series")] {
                let path = try XCTUnwrap(target.path(forResource: language, ofType: "lproj"), relativePath)
                let bundle = try XCTUnwrap(Bundle(path: path))
                XCTAssertEqual(bundle.localizedString(forKey: "Sets", value: nil, table: nil), expected, relativePath)
            }
        }
    }
}
