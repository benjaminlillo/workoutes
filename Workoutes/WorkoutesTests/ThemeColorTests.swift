import SwiftUI
import SwiftData
import UIKit
import XCTest
@testable import Workoutes

@MainActor
final class ThemeColorTests: XCTestCase {
    func testVisibleSettingsValuesFollowEveryAccentChange() async throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "appAccentColor")
        defer {
            if let previous { defaults.set(previous, forKey: "appAccentColor") }
            else { defaults.removeObject(forKey: "appAccentColor") }
        }
        defaults.set(ThemeColor.sunsetPop.rawValue, forKey: "appAccentColor")
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
        // Reuse the same visible Settings screen to catch cached accent labels.
        for theme in ThemeColor.allCases {
            defaults.set(theme.rawValue, forKey: "appAccentColor")
            for scheme in [ColorScheme.light, .dark] {
                window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
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
                let rgb = try XCTUnwrap(UInt32(theme.hex(for: scheme), radix: 16))
                let target = [Int(rgb >> 16), Int((rgb >> 8) & 255), Int(rgb & 255)]
                // These bands contain the theme value and weight picker; the gradient and faint border
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
                    XCTAssertGreaterThan(matches, 150, "Settings value did not update to \(theme.name) in \(scheme)")
                }
                try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-settings-live-accent-\(theme.rawValue)-\(scheme).png"))
            }
        }
    }

    func testPaletteMatchesProvidedColorsInLightAndDarkMode() {
        let light = ["6C3DD1", "3D52F5", "D12D78",
                     "5621B6", "1745A3", "AE194F", "1C2D50"]
        let dark = ["B784E8", "32D5E5", "FF8059",
                    "B9EE4A", "FF985C", "55D6CF", "F6C85F"]
        XCTAssertEqual(ThemeColor.allCases.map(\.hex), light)
        XCTAssertEqual(ThemeColor.allCases.map(\.secondaryHex),
                       dark)
        XCTAssertEqual(ThemeColor.allCases.map(\.tertiaryHex),
                       ["F3DDF2", "D5F66A", "FFD65C",
                        "F0FFD0", "FFF1CB", "D9FFF7", "FFF1C7"])
        XCTAssertEqual(ThemeColor.allCases.map(\.name),
                       ["Violet Aura", "Electric Rush", "Sunset Pop",
                        "Ultravolt", "Cobalt Heat", "Cherry Ice", "Midnight Gold"])
        for style in [UIUserInterfaceStyle.light, .dark] {
            let actual = ThemeColor.allCases.map { theme in
                Color(uiColor: UIColor(theme.color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))).toHex()
            }
            XCTAssertEqual(actual, style == .dark ? dark : light)
            XCTAssertEqual(ThemeColor.allCases.map { $0.hex(for: style == .dark ? .dark : .light) }, actual)
        }
    }

    func testPreviousSelectionsResolveToAnAvailablePaletteOption() {
        for theme in ThemeColor.allCases {
            XCTAssertEqual(ThemeColor.resolve(theme.rawValue), theme)
        }
        for retired in ["primary", "mint", "purple", "orange", "blue", "green", "red"] {
            XCTAssertNil(ThemeColor(rawValue: retired))
            XCTAssertEqual(ThemeColor.resolve(retired), .indigo)
        }
        XCTAssertEqual(ThemeColor.resolve(nil), .indigo)
        XCTAssertEqual(ThemeColor.resolve("unknown-color"), .indigo)
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
        for (stored, expected) in [("primary", "B784E8"), ("indigo", "B784E8"), ("mint", "B784E8"),
                                   ("purple", "B784E8"), ("orange", "B784E8"), ("electricRush", "32D5E5"),
                                   ("sunsetPop", "FF8059"), ("ultravolt", "B9EE4A"), ("cobaltHeat", "FF985C"),
                                   ("cherryIce", "55D6CF"), ("midnightGold", "F6C85F"),
                                   ("blue", "B784E8"), ("green", "B784E8"), ("red", "B784E8")] {
            defaults.set(stored, forKey: "appAccentColor")
            XCTAssertEqual(exercise.activityContent.accentColorHex, expected)
        }
    }
}
