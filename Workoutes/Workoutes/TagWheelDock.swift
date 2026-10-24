import Foundation
import CoreGraphics

/// Stores an edge and a proportional position so docking also survives screen-size changes.
nonisolated struct TagWheelDock: Codable, Equatable {
    enum Edge: String, Codable, CaseIterable {
        case trailing, leading, top, bottom

    }

    let edge: Edge
    let fraction: Double

    var selectionAngle: Double {
        switch edge {
        case .trailing: fraction < 0.5 ? 3 * .pi / 4 : -3 * .pi / 4
        case .leading: fraction < 0.5 ? .pi / 4 : -.pi / 4
        case .top: fraction < 0.5 ? .pi / 4 : 3 * .pi / 4
        case .bottom: fraction < 0.5 ? -.pi / 4 : -3 * .pi / 4
        }
    }

    func center(in bounds: CGRect) -> CGPoint {
        let fraction = min(1, max(0, fraction))
        switch edge {
        case .leading: return CGPoint(x: bounds.minX, y: bounds.minY + bounds.height * fraction)
        case .trailing: return CGPoint(x: bounds.maxX, y: bounds.minY + bounds.height * fraction)
        case .top: return CGPoint(x: bounds.minX + bounds.width * fraction, y: bounds.minY)
        case .bottom: return CGPoint(x: bounds.minX + bounds.width * fraction, y: bounds.maxY)
        }
    }

    static func nearest(to point: CGPoint, in bounds: CGRect, preferredEdge: Edge = .trailing) -> Self {
        let point = clamped(point, in: bounds)
        let distances: [Edge: CGFloat] = [.leading: point.x - bounds.minX, .trailing: bounds.maxX - point.x,
                                          .top: point.y - bounds.minY, .bottom: bounds.maxY - point.y]
        let edges = [preferredEdge] + Edge.allCases.filter { $0 != preferredEdge }
        let edge = edges.min { distances[$0, default: 0] < distances[$1, default: 0] } ?? preferredEdge
        let fraction: Double
        switch edge {
        case .leading, .trailing: fraction = bounds.height > 0 ? (point.y - bounds.minY) / bounds.height : 0.5
        case .top, .bottom: fraction = bounds.width > 0 ? (point.x - bounds.minX) / bounds.width : 0.5
        }
        return Self(edge: edge, fraction: fraction)
    }

    static func clamped(_ point: CGPoint, in bounds: CGRect) -> CGPoint {
        CGPoint(x: min(bounds.maxX, max(bounds.minX, point.x)),
                y: min(bounds.maxY, max(bounds.minY, point.y)))
    }

    static func decode(_ rawValue: String) -> Self? {
        guard let value = try? JSONDecoder().decode(Self.self, from: Data(rawValue.utf8)),
              value.fraction.isFinite, (0...1).contains(value.fraction) else { return nil }
        return value
    }

    var encoded: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
