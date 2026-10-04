import SwiftUI
import SwiftData
import UIKit
import XCTest
@testable import Workoutes

@MainActor
final class ThemeColorTests: XCTestCase {
    func testVisibleSettingsPickerLabelsFollowEveryAccentChange() async throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "appAccentColor")
        defer {
            if let previous { defaults.set(previous, forKey: "appAccentColor") }
            else { defaults.removeObject(forKey: "appAccentColor") }
        }
        defaults.set(ThemeColor.orange.rawValue, forKey: "appAccentColor")
        let container = try ModelContainer(for: Workout.self, WorkoutExercise.self, Tag.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: SettingsView()
            .environment(\.dynamicTypeSize, .large).modelContainer(container))
        window.overrideUserInterfaceStyle = .light
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(300))
        // Reuse the same visible Settings screen, reproducing the cached orange label.
        for theme in ThemeColor.allCases {
            defaults.set(theme.rawValue, forKey: "appAccentColor")
            try await Task.sleep(for: .milliseconds(300))
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let cgImage = try XCTUnwrap(image.cgImage)
            let width = cgImage.width
            let height = cgImage.height
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height,
                                                 bitsPerComponent: 8, bytesPerRow: width * 4,
                                                 space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            let rgb = try XCTUnwrap(UInt32(theme.hex, radix: 16))
            let target = [Int(rgb >> 16), Int((rgb >> 8) & 255), Int(rgb & 255)]
            // These bands contain the two menu pickers; the gradient and faint border
            // cannot match the solid accent used by the selected value and arrows.
            for band in [140.0...220.0, 250.0...330.0] {
                var matches = 0
                let top = Double(window.safeAreaInsets.top)
                let scale = Double(image.scale)
                let start = max(0, Int((top + band.lowerBound) * scale))
                let end = min(height, Int((top + band.upperBound) * scale))
                for y in start..<end {
                    for x in Int(Double(width) * 0.55)..<Int(Double(width) * 0.95) {
                        let index = (y * width + x) * 4
                        if (0..<3).allSatisfy({ abs(Int(pixels[index + $0]) - target[$0]) <= 2 }) { matches += 1 }
                    }
                }
                XCTAssertGreaterThan(matches, 150, "Picker label did not update to \(theme.name)")
            }
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-settings-live-accent-\(theme.rawValue).png"))
        }
    }

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
