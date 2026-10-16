import Foundation

/// One evenly spaced position per tag, with continuous rotation across the atan2 seam.
nonisolated struct TagWheelPosition {
    static let selectionAngle = -3 * Double.pi / 4
    private(set) var position: Double = 0
    private var previousDragAngle: Double?

    static func angularSpacing(for count: Int) -> Double {
        2 * .pi / Double(max(count, 1))
    }

    static func wrappedIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (index % count + count) % count
    }

    func selectedIndex(count: Int) -> Int {
        Self.wrappedIndex(Int(position.rounded()), count: count)
    }

    mutating func drag(to angle: Double, count: Int) {
        defer { previousDragAngle = angle }
        guard count > 1, let previousDragAngle else { return }
        let delta = angle - previousDragAngle
        // atan2 crosses from +π to -π at the left edge; unwrap that crossing.
        let unwrapped = atan2(sin(delta), cos(delta))
        position += unwrapped / Self.angularSpacing(for: count)
    }

    mutating func snap() {
        position = position.rounded()
        previousDragAngle = nil
    }

    mutating func select(_ index: Int, count: Int) {
        guard count > 0 else { return }
        guard count > 1 else {
            position = 0
            previousDragAngle = nil
            return
        }
        let cycle = Double(count)
        let target = Double(index) + ((position - Double(index)) / cycle).rounded() * cycle
        selectPosition(Int(target))
    }

    mutating func selectPosition(_ target: Int) {
        position = Double(target)
        previousDragAngle = nil
    }

    func index(at angle: Double, count: Int) -> Int {
        let target = position + (Self.selectionAngle - angle) / Self.angularSpacing(for: count)
        return Self.wrappedIndex(Int(target.rounded()), count: count)
    }
}
