import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class TagWheelDockTests: XCTestCase {
    private let bounds = CGRect(x: 34, y: 96, width: 334, height: 640)

    func testReleaseChoosesTheClosestEdgeWithoutLosingItsPositionAlongThatEdge() {
        let cases: [(CGPoint, TagWheelDock.Edge)] = [
            (CGPoint(x: 50, y: 300), .leading), (CGPoint(x: 350, y: 500), .trailing),
            (CGPoint(x: 200, y: 110), .top), (CGPoint(x: 200, y: 720), .bottom)
        ]
        for (point, edge) in cases {
            let dock = TagWheelDock.nearest(to: point, in: bounds)
            XCTAssertEqual(dock.edge, edge)
            let center = dock.center(in: bounds)
            switch edge {
            case .leading: XCTAssertEqual(center.x, bounds.minX); XCTAssertEqual(center.y, point.y)
            case .trailing: XCTAssertEqual(center.x, bounds.maxX); XCTAssertEqual(center.y, point.y)
            case .top: XCTAssertEqual(center.y, bounds.minY); XCTAssertEqual(center.x, point.x)
            case .bottom: XCTAssertEqual(center.y, bounds.maxY); XCTAssertEqual(center.x, point.x)
            }
        }
    }

    func testOutOfBoundsReleasesAndTiesAreStable() {
        for point in [CGPoint(x: -500, y: -500), CGPoint(x: 900, y: 1_500), CGPoint(x: 200, y: 300)] {
            let dock = TagWheelDock.nearest(to: point, in: bounds)
            XCTAssertTrue((0...1).contains(dock.fraction))
            let center = dock.center(in: bounds)
            XCTAssertTrue(center.x == bounds.minX || center.x == bounds.maxX
                          || center.y == bounds.minY || center.y == bounds.maxY)
        }
        let middle = CGPoint(x: bounds.midX, y: bounds.midY)
        XCTAssertEqual(TagWheelDock.nearest(to: middle, in: bounds, preferredEdge: .leading).edge, .leading)
        XCTAssertEqual(TagWheelDock.nearest(to: middle, in: bounds, preferredEdge: .trailing).edge, .trailing)
        let tiny = CGRect(x: 10, y: 10, width: 0, height: 0)
        XCTAssertEqual(TagWheelDock.nearest(to: .zero, in: tiny).center(in: tiny), tiny.origin)
    }

    func testSavedPositionSurvivesReloadAndAdaptsToAnotherScreenSize() throws {
        let dock = TagWheelDock(edge: .leading, fraction: 0.7)
        let restored = try XCTUnwrap(TagWheelDock.decode(dock.encoded))
        XCTAssertEqual(restored, dock)
        let landscape = CGRect(x: 80, y: 34, width: 650, height: 210)
        XCTAssertEqual(restored.center(in: landscape).x, landscape.minX)
        XCTAssertEqual(restored.center(in: landscape).y, landscape.minY + landscape.height * 0.7, accuracy: 0.001)
        for value in ["", "invalid", "{}", "{\"edge\":\"leading\",\"fraction\":-0.1}",
                      "{\"edge\":\"trailing\",\"fraction\":1.1}", "{\"edge\":\"unknown\",\"fraction\":0.5}"] {
            XCTAssertNil(TagWheelDock.decode(value))
        }
    }

    func testSelectedSectorFacesInwardsAndTapsStillResolveTheSameTagAtEveryEdge() {
        var wheel = TagWheelPosition()
        wheel.select(3, count: 8)
        for edge in TagWheelDock.Edge.allCases {
            for fraction in [0.1, 0.9] {
                let dock = TagWheelDock(edge: edge, fraction: fraction)
                let center = dock.center(in: bounds)
                let icon = CGPoint(x: center.x + cos(dock.selectionAngle) * 69,
                                   y: center.y + sin(dock.selectionAngle) * 69)
                XCTAssertGreaterThan(icon.x, bounds.minX)
                XCTAssertLessThan(icon.x, bounds.maxX)
                XCTAssertGreaterThan(icon.y, bounds.minY)
                XCTAssertLessThan(icon.y, bounds.maxY)
                for index in 0..<8 {
                    let angle = dock.selectionAngle - (Double(index) - wheel.position) * TagWheelPosition.angularSpacing(for: 8)
                    XCTAssertEqual(wheel.index(at: angle, count: 8, referenceAngle: dock.selectionAngle), index)
                }
            }
        }
        XCTAssertEqual(wheel.selectedIndex(count: 8), 3)
    }

    func testSavedDockIsRestoredByTheViewAndTheHubStaysVisible() async throws {
        let suiteName = "TagWheelDockTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true }

        for edge in TagWheelDock.Edge.allCases {
            defaults.set(TagWheelDock(edge: edge, fraction: 0.4).encoded, forKey: "tagWheelDockPosition")
            window.rootViewController = UIHostingController(rootView:
                Color.clear.overlay {
                    DockableTagWheel(tags: [], selection: .constant(nil), onAdd: {}, onEdit: { _ in }, onDelete: { _ in })
                }.defaultAppStorage(defaults))
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(150))
            let button = try XCTUnwrap(findHub(in: try XCTUnwrap(window.rootViewController).view))
            let frame = button.convert(button.bounds, to: window)
            XCTAssertGreaterThanOrEqual(frame.minX, window.safeAreaInsets.left)
            XCTAssertLessThanOrEqual(frame.maxX, window.bounds.maxX - window.safeAreaInsets.right)
            XCTAssertGreaterThanOrEqual(frame.minY, window.safeAreaInsets.top)
            XCTAssertLessThanOrEqual(frame.maxY, window.bounds.maxY - window.safeAreaInsets.bottom - 64)
            if edge == .leading { XCTAssertEqual(frame.midX, window.safeAreaInsets.left + DockableTagWheel.hubInset, accuracy: 0.5) }
            if edge == .trailing { XCTAssertEqual(frame.midX, window.bounds.maxX - window.safeAreaInsets.right - DockableTagWheel.hubInset, accuracy: 0.5) }
        }
    }

    private func findHub(in view: UIView) -> TagWheelGripView? {
        if let hub = view as? TagWheelGripView { return hub }
        return view.subviews.compactMap { findHub(in: $0) }.first
    }
}
