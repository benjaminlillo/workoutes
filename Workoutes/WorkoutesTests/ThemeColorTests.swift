import SwiftUI
import UIKit
import XCTest
@testable import Workoutes

@MainActor
final class ThemeColorTests: XCTestCase {
    func testPaletteMatchesProvidedColorsInLightAndDarkMode() {
        let expected = ["326884", "6155F5", "D2F1E4", "42213D", "F15025"]
        XCTAssertEqual(ThemeColor.allCases.map(\.hex), expected)
        XCTAssertEqual(ThemeColor.allCases.map(\.name),
                       ["Blue Slate", "Majorelle Blue", "Frozen Water", "Midnight Violet", "Blazing Flame"])
        for style in [UIUserInterfaceStyle.light, .dark] {
            let actual = ThemeColor.allCases.map { theme in
                Color(uiColor: UIColor(theme.color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))).toHex()
            }
            XCTAssertEqual(actual, expected)
        }
    }

    func testPreviousSelectionsResolveToAnAvailablePaletteOption() {
        for theme in ThemeColor.allCases {
            XCTAssertEqual(ThemeColor.resolve(theme.rawValue), theme)
        }
        XCTAssertEqual(ThemeColor.resolve("blue"), .indigo)
        XCTAssertEqual(ThemeColor.resolve("green"), .mint)
        XCTAssertEqual(ThemeColor.resolve("red"), .orange)
        XCTAssertEqual(ThemeColor.resolve(nil), .primary)
        XCTAssertEqual(ThemeColor.resolve("unknown-color"), .primary)
    }

    func testLiveActivityUsesResolvedPaletteHex() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "appAccentColor")
        defer {
            if let previous { defaults.set(previous, forKey: "appAccentColor") }
            else { defaults.removeObject(forKey: "appAccentColor") }
        }
        let exercise = WorkoutExercise(title: "Bench Press", subtitle: "Chest", details: "",
                                       numberOfSets: 3, reps: 10, increaseLoadNextTime: false, weight: 20)
        for (stored, expected) in [("indigo", "6155F5"), ("mint", "D2F1E4"), ("purple", "42213D"),
                                   ("orange", "F15025"), ("blue", "6155F5"), ("green", "D2F1E4"), ("red", "F15025")] {
            defaults.set(stored, forKey: "appAccentColor")
            XCTAssertEqual(exercise.activityContent.accentColorHex, expected)
        }
    }
}
