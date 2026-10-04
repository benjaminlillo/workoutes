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
        let expected = Set(["WorkoutesIcon-majorelle-blue", "WorkoutesIcon-frozen-water",
                            "WorkoutesIcon-midnight-violet", "WorkoutesIcon-blazing-flame"])
        XCTAssertNil(ThemeColor.primary.alternateIconName)
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

    func testKeepsTheCurrentIconAndCanReturnToBlueSlate() async {
        let application = IconApplication()
        application.alternateIconName = ThemeColor.purple.alternateIconName
        let controller = ThemeIconController(application: application)
        await controller.update(for: .purple)
        XCTAssertTrue(application.requests.isEmpty)
        await controller.update(for: .primary)
        XCTAssertEqual(application.requests.count, 1)
        XCTAssertNil(application.requests[0])
        XCTAssertNil(application.alternateIconName)
    }

    func testQuickSelectionsAreSerializedAndTheLatestThemeWins() async throws {
        let application = IconApplication()
        application.blockNextRequest = true
        let controller = ThemeIconController(application: application)
        let first = Task { await controller.update(for: .indigo) }
        for _ in 0..<100 {
            if application.continuation != nil { break }
            await Task.yield()
        }
        let continuation = try XCTUnwrap(application.continuation)
        await controller.update(for: .mint)
        await controller.update(for: .purple)
        continuation.resume()
        application.continuation = nil
        await first.value
        XCTAssertEqual(application.requests, [ThemeColor.indigo.alternateIconName, ThemeColor.purple.alternateIconName])
        XCTAssertEqual(application.alternateIconName, ThemeColor.purple.alternateIconName)
    }

    func testReportsFailuresAndRecoversOnAnotherThemeSelection() async {
        let application = IconApplication()
        application.shouldFail = true
        let controller = ThemeIconController(application: application)
        await controller.update(for: .mint)
        XCTAssertNotNil(controller.errorMessage)
        XCTAssertNil(application.alternateIconName)
        application.shouldFail = false
        await controller.update(for: .orange)
        XCTAssertNil(controller.errorMessage)
        XCTAssertEqual(application.alternateIconName, ThemeColor.orange.alternateIconName)
    }

    func testDoesNotRequestAnIconOnAnUnsupportedPlatform() async {
        let application = IconApplication()
        application.supportsAlternateIcons = false
        let controller = ThemeIconController(application: application)
        await controller.update(for: .indigo)
        XCTAssertTrue(application.requests.isEmpty)
        XCTAssertNil(controller.errorMessage)
    }
}
