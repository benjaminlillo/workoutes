import XCTest
@testable import Workoutes

@MainActor
final class ThemeIconTests: XCTestCase {
    private final class IconApplication: AppIconUpdating {
        var supportsAlternateIcons = true
        var alternateIconName: String?
        var requests: [String?] = []
        var shouldFail = false
        var blockNextRequest = false
        var continuation: CheckedContinuation<Void, Never>?

        func setAlternateIconName(_ name: String?) async throws {
            requests.append(name)
            if blockNextRequest {
                blockNextRequest = false
                await withCheckedContinuation { continuation = $0 }
            }
            if shouldFail { throw NSError(domain: "IconTest", code: 1) }
            alternateIconName = name
        }
    }

    func testEveryThemeIconIsRegisteredForIPhoneAndIPad() throws {
        let expected = Set(["WorkoutesIcon-electric-rush", "WorkoutesIcon-sunset-pop",
                            "WorkoutesIcon-ultravolt", "WorkoutesIcon-cobalt-heat",
                            "WorkoutesIcon-cherry-ice", "WorkoutesIcon-midnight-gold"])
        XCTAssertNil(ThemeColor.indigo.alternateIconName)
        XCTAssertEqual(Set(ThemeColor.allCases.compactMap(\.alternateIconName)), expected)
        let data = try Data(contentsOf: Bundle.main.bundleURL.appendingPathComponent("Info.plist"))
        let info = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
            let icons = try XCTUnwrap(info[key] as? [String: Any], "Missing \(key) in \(Bundle.main.bundlePath)")
            let primary = try XCTUnwrap(icons["CFBundlePrimaryIcon"] as? [String: Any])
            XCTAssertEqual(primary["CFBundleIconName"] as? String, "WorkoutesIcon")
            let alternates = try XCTUnwrap(icons["CFBundleAlternateIcons"] as? [String: [String: Any]])
            XCTAssertEqual(Set(alternates.keys), expected)
            for (name, info) in alternates {
                XCTAssertEqual(info["CFBundleIconName"] as? String, name)
            }
        }
    }

    func testKeepsTheCurrentIconAndCanReturnToVioletAura() async {
        let application = IconApplication()
        application.alternateIconName = ThemeColor.ultravolt.alternateIconName
        let controller = ThemeIconController(application: application)
        await controller.update(for: .ultravolt)
        XCTAssertTrue(application.requests.isEmpty)
        await controller.update(for: .indigo)
        XCTAssertEqual(application.requests.count, 1)
        XCTAssertNil(application.requests[0])
        XCTAssertNil(application.alternateIconName)
    }

    func testRetiredThemeIconsMigrateToVioletAura() async {
        let previous: [(String, String?)] = [
            ("primary", nil),
            ("mint", "WorkoutesIcon-frozen-water"),
            ("purple", "WorkoutesIcon-midnight-violet"),
            ("orange", "WorkoutesIcon-blazing-flame"),
            ("indigo", "WorkoutesIcon-majorelle-blue")
        ]
        for (stored, icon) in previous {
            let application = IconApplication()
            application.alternateIconName = icon
            let controller = ThemeIconController(application: application)
            await controller.update(for: ThemeColor.resolve(stored))
            XCTAssertNil(application.alternateIconName)
            XCTAssertEqual(application.requests.count, icon == nil ? 0 : 1)
            XCTAssertNil(controller.errorMessage)
        }
    }

    func testQuickSelectionsAreSerializedAndTheLatestThemeWins() async throws {
        let application = IconApplication()
        application.blockNextRequest = true
        let controller = ThemeIconController(application: application)
        let first = Task { await controller.update(for: .electricRush) }
        for _ in 0..<100 {
            if application.continuation != nil { break }
            await Task.yield()
        }
        let continuation = try XCTUnwrap(application.continuation)
        await controller.update(for: .cherryIce)
        await controller.update(for: .ultravolt)
        continuation.resume()
        application.continuation = nil
        await first.value
        XCTAssertEqual(application.requests, [ThemeColor.electricRush.alternateIconName, ThemeColor.ultravolt.alternateIconName])
        XCTAssertEqual(application.alternateIconName, ThemeColor.ultravolt.alternateIconName)
    }

    func testReportsFailuresAndRecoversOnAnotherThemeSelection() async {
        let application = IconApplication()
        application.shouldFail = true
        let controller = ThemeIconController(application: application)
        await controller.update(for: .cherryIce)
        XCTAssertNotNil(controller.errorMessage)
        XCTAssertNil(application.alternateIconName)
        application.shouldFail = false
        await controller.update(for: .sunsetPop)
        XCTAssertNil(controller.errorMessage)
        XCTAssertEqual(application.alternateIconName, ThemeColor.sunsetPop.alternateIconName)
    }

    func testDoesNotRequestAnIconOnAnUnsupportedPlatform() async {
        let application = IconApplication()
        application.supportsAlternateIcons = false
        let controller = ThemeIconController(application: application)
        await controller.update(for: .electricRush)
        XCTAssertTrue(application.requests.isEmpty)
        XCTAssertNil(controller.errorMessage)
    }
}
